#!/usr/bin/env bash
# Run from the workspace root holding harness/ (this branch), old/ (master) and new/ (aes-0.9).
# Each variant is built as a dependent crate, outside the WarpCrypto checkout, so the
# repo's own .cargo/config.toml does not apply (the situation of a crate depending on warpcrypto).
set -euo pipefail
arch=$(uname -m)
rustc -V
echo "cpu: $(grep -m1 -E '^(model name|CPU part)' /proc/cpuinfo || true)"
echo "aes flags: $(grep -m1 -E '^(flags|Features)' /proc/cpuinfo | tr ' ' '\n' | grep -x -E 'aes|pmull' | sort -u | tr '\n' ' ')"
echo "old: $(git -C old rev-parse HEAD)  new: $(git -C new rev-parse HEAD)"

variants="old new"
[ "$arch" = aarch64 ] && variants="old old+aes_armv8 new"

for v in $variants; do
  src=old feat="" flags=""
  case $v in
    new) src=new feat="--features new" ;;
    old+aes_armv8) flags="--cfg aes_armv8" ;;
  esac
  dir="b-${v//+/_}"
  cp -r harness/bench "$dir"
  sed -i "s#path = \"../wc\"#path = \"../$src\"#" "$dir/Cargo.toml"
  (cd "$dir" && RUSTFLAGS="$flags" cargo build --release --quiet $feat && cargo tree -e normal -i aes --depth 0 $feat)
done

for pass in 1 2 3 4 5; do
  for v in $variants; do
    "b-${v//+/_}/target/release/wcbench" "$arch" "$v" "$pass"
  done
done
