#!/usr/bin/env bash
# Run from the workspace root holding harness/ (this branch), old/ (master), a/ (aes-0.9) and b/ (aes-0.9-wipe).
# Each variant is built as a dependent crate, outside the WarpCrypto checkout, so the
# repo's own .cargo/config.toml does not apply (the situation of a crate depending on warpcrypto).
set -euo pipefail
arch=$(uname -m)
rustc -V
echo "cpu: $(grep -m1 -E '^(model name|CPU part)' /proc/cpuinfo || true)"
echo "aes flags: $(grep -m1 -E '^(flags|Features)' /proc/cpuinfo | tr ' ' '\n' | grep -x -E 'aes|pmull' | sort -u | tr '\n' ' ')"
echo "old: $(git -C old rev-parse HEAD)  a: $(git -C a rev-parse HEAD)  b: $(git -C b rev-parse HEAD)"

variants="old a b"
[ "$arch" = aarch64 ] && variants="old old+aes_armv8 a b"

for v in $variants; do
  src=old feat="" flags="" aesver="=0.9.2"
  case $v in
    a) src=a feat="--features new" ;;
    b) src=b feat="--features new" ;;
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
