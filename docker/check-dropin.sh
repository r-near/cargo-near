#!/usr/bin/env bash
# Build one contract in several images with identical NEP-330 inputs and
# fail unless every image produces byte-identical wasm.
#
#   docker/check-dropin.sh <src-dir> <contract-path> <image>... -- <build command...>
set -euo pipefail

src=$1
contract_path=$2
shift 2
images=()
while [ "$1" != "--" ]; do
  images+=("$1")
  shift
done
shift

hashes=()
for image in "${images[@]}"; do
  work=$(mktemp -d)
  cp -a "$src/." "$work/"
  rm -rf "$work/target"
  docker run --rm -u "$(id -u):$(id -g)" \
    -v "$work:/home/near/code" -w "/home/near/code/$contract_path" \
    -e NEP330_BUILD_INFO_BUILD_ENVIRONMENT="dropin-check@sha256:$(printf '0%.0s' {1..64})" \
    -e NEP330_BUILD_INFO_SOURCE_CODE_SNAPSHOT="git+https://example.com/dropin-check?rev=$(printf '0%.0s' {1..40})" \
    -e NEP330_BUILD_INFO_CONTRACT_PATH="$contract_path" \
    -e NEP330_LINK=https://example.com/dropin-check \
    "$image" bash -c "$*"
  wasm=$(find "$work/target/near" -name '*.wasm' | sort)
  hash=$(sha256sum $wasm | cut -d' ' -f1 | tr '\n' ' ')
  echo "$hash $image"
  hashes+=("$hash")
done

for hash in "${hashes[@]}"; do
  if [ "$hash" != "${hashes[0]}" ]; then
    echo "wasm differs between images" >&2
    exit 1
  fi
done
