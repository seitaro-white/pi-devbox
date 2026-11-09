#!/usr/bin/env bash
# Run on the Docker host after make build. Never removes the old volumes.
set -euo pipefail
cd "$(dirname "$0")/.."

config=$(docker compose config --format json)
settings=$(node -e '
  const c = JSON.parse(process.argv[1]);
  const s = c.services["pi-box"];
  const state = s.volumes.find(v => v.type === "volume" && v.target === "/state");
  if (!state || !s.container_name || !s.image) throw Error("Expected the new Compose state layout");
  console.log([c.name, s.container_name, s.image, c.volumes[state.source].name].join("\t"));
' "$config")
IFS=$'\t' read -r project container image state <<< "$settings"

volumes=$(docker volume ls --format '{{.Name}}')
if grep -Fxq -- "$state" <<< "$volumes"; then
    echo "Target volume $state already exists; refusing migration." >&2
    exit 1
fi
docker image inspect "$image" | node -e '
  let text = ""; process.stdin.on("data", d => text += d).on("end", () => {
    if (!JSON.parse(text)[0].Config.Env.includes("GIT_CONFIG_GLOBAL=/state/git/config"))
      throw Error("Run make build first");
  });
'
metadata=$(docker container inspect "$container")
sources=$(node -e '
  const c = JSON.parse(process.argv[1])[0];
  const labels = c.Config.Labels || {};
  if (!c.State.Running || !labels["com.docker.compose.config-hash"] ||
      labels["com.docker.compose.project"] !== process.argv[2] ||
      labels["com.docker.compose.service"] !== "pi-box")
    throw Error("Expected the running old Compose container");
  const paths = ["/workspace", "/home/node/.pi/agent", "/home/node/.config/git", "/home/node/.herdr"];
  const mounts = paths.map(p => c.Mounts.find(m => m.Destination === p && m.Type === "volume" && m.RW));
  if (c.Mounts.length !== 4 || mounts.some(m => !m) || new Set(mounts.map(m => m.Name)).size !== 4)
    throw Error("Expected exactly the old four writable named volumes");
  console.log(mounts.slice(1).map(m => m.Name).join("\t"));
' "$metadata" "$project")
IFS=$'\t' read -r agent git herdr <<< "$sources"
for volume in "$agent" "$git" "$herdr"; do
    users=$(docker ps --filter "volume=$volume" --format '{{.Names}}')
    if [[ "$users" != "$container" ]]; then
        echo "Volume $volume is shared or not mounted by $container; handle it manually." >&2
        exit 1
    fi
done

docker exec -i "$container" sh -s < scripts/check-disposable-files.sh
docker stop "$container"
docker rm "$container"

# --mount refuses missing source volumes instead of silently creating them.
docker volume create "$state" > /dev/null
docker run --rm -i --user root --entrypoint bash \
    --mount "type=volume,src=$agent,dst=/old/agent,readonly" \
    --mount "type=volume,src=$git,dst=/old/git,readonly" \
    --mount "type=volume,src=$herdr,dst=/old/herdr,readonly" \
    --mount "type=volume,src=$state,dst=/state" "$image" -s <<'COPY'
set -euo pipefail
shopt -s dotglob nullglob
for path in /old/agent/*; do
    case ${path##*/} in
        gcloud|claude) cp -a "$path/." "/state/${path##*/}/" ;;
        python|uv-tools|bin|tools) ;;
        *) cp -a "$path" /state/pi/ ;;
    esac
done
cp -a /old/git/. /state/git/
cp -a /old/herdr/. /state/herdr/
echo 'Python and uv tools were not copied (their absolute paths would break). Reinstall inside the new container:'
for path in /old/agent/python/*; do
    name=${path##*/}
    if [[ $name =~ ^cpython-([0-9]+\.[0-9]+\.[0-9]+)- ]]; then
        printf '  uv python install %q\n' "${BASH_REMATCH[1]}"
    fi
done
for path in /old/agent/uv-tools/*; do
    [[ -d $path && ${path##*/} != .* ]] || continue
    printf '  uv tool install %q\n' "${path##*/}"
done
echo 'Reinstall any other legacy python/, bin/ or tools/ installs manually.'
COPY

printf '\nMigration complete. Run make up. Old volumes are untouched; after verifying, remove them with:\n'
printf 'docker volume rm %q %q %q\n' "$agent" "$git" "$herdr"
