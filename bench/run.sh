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

# Diagnostics, never shipped: the branch without aes's zeroize feature, and the branch on aes 0.9.4.
cp -r new new-nozeroize
sed -i 's/^features = \["zeroize"\]$//' new-nozeroize/Cargo.toml
cp -r new new-aes094
sed -i 's/^version = ">=0.9.2, <0.9.3"$/version = "=0.9.4"/' new-aes094/Cargo.toml
grep -A3 'dependencies.aes' new-nozeroize/Cargo.toml new-aes094/Cargo.toml

variants="old new new-nozeroize new-aes094"
[ "$arch" = aarch64 ] && variants="old old+aes_armv8 new new-nozeroize new-aes094"

for v in $variants; do
  src=old feat="" flags="" aesver="=0.9.2"
  case $v in
    new) src=new feat="--features new" ;;
    new-nozeroize) src=new-nozeroize feat="--features new" ;;
    new-aes094) src=new-aes094 feat="--features new" aesver="=0.9.4" ;;
    old+aes_armv8) flags="--cfg aes_armv8" ;;
  esac
  dir="b-${v//+/_}"
  cp -r harness/bench "$dir"
  sed -i "s#path = \"../wc\"#path = \"../$src\"#; s#version = \"=0.9.2\"#version = \"$aesver\"#" "$dir/Cargo.toml"
  (cd "$dir" && RUSTFLAGS="$flags" cargo build --release --quiet $feat && cargo tree -e normal,features -i aes --depth 1 $feat)
done

for pass in 1 2 3 4 5; do
  for v in $variants; do
    "b-${v//+/_}/target/release/wcbench" "$arch" "$v" "$pass"
  done
done
