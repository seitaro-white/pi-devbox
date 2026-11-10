#!/bin/sh
set -eu

# Keep in sync with the Dockerfile's mise image; npm test checks the version.
mise_version=2026.10.25
case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)
        mise_arch=x64
        mise_sha256=5d362ecc578dc7c146679b841dda949d6472cbf86ff5635db7afdca1b6b3fd87
        ;;
    Linux/aarch64|Linux/arm64)
        mise_arch=arm64
        mise_sha256=bb09e88b13164ca90691a5cc042726d079f0ba26ab55527344cb173c2e83c998
        ;;
    *) echo 'lock-tools requires Linux x64 or arm64' >&2; exit 1 ;;
esac

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
download_dir=$(mktemp -d)
trap 'rm -rf "$download_dir"' EXIT
trap 'exit 1' HUP INT TERM

curl -fsSL "https://github.com/jdx/mise/releases/download/v${mise_version}/mise-v${mise_version}-linux-${mise_arch}" -o "$download_dir/mise"
printf '%s  %s\n' "$mise_sha256" "$download_dir/mise" | sha256sum -c -
chmod +x "$download_dir/mise"

# Trust and resolver caches must not leave anything in HOME or /state.
export MISE_DATA_DIR="$download_dir/data" MISE_CACHE_DIR="$download_dir/cache"
export MISE_CONFIG_DIR="$download_dir/config" MISE_STATE_DIR="$download_dir/state"
"$download_dir/mise" -C "$repo_root/container" trust
"$download_dir/mise" -C "$repo_root/container" lock --platform linux-x64,linux-arm64
