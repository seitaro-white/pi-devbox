#!/bin/sh
set -eu

# Keep in sync with the Dockerfile's mise image; npm test checks the version.
version=2026.10.25
case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)
        arch=x64
        checksum=5d362ecc578dc7c146679b841dda949d6472cbf86ff5635db7afdca1b6b3fd87
        ;;
    Linux/aarch64|Linux/arm64)
        arch=arm64
        checksum=bb09e88b13164ca90691a5cc042726d079f0ba26ab55527344cb173c2e83c998
        ;;
    *) echo 'lock-tools requires Linux x64 or arm64' >&2; exit 1 ;;
esac

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM

curl -fsSL "https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-linux-${arch}" -o "$tmp/mise"
printf '%s  %s\n' "$checksum" "$tmp/mise" | sha256sum -c -
chmod +x "$tmp/mise"

# Trust and resolver caches must not leave anything in HOME or /state.
export MISE_DATA_DIR="$tmp/data" MISE_CACHE_DIR="$tmp/cache"
export MISE_CONFIG_DIR="$tmp/config" MISE_STATE_DIR="$tmp/state"
"$tmp/mise" -C "$root/container" trust
"$tmp/mise" -C "$root/container" lock --platform linux-x64,linux-arm64
