#!/bin/bash
set -euo pipefail
#set -x

## Run a Rust libstd test suite with Miri.
## Assumes Miri to be installed.
## Usage:
##   ./run-test.sh CRATE_NAME CARGO_TEST_ARGS
## Environment variables:
##   MIRI_LIB_SRC: The path to the Rust library directory (`library`).
##     Defaults to `$(rustc --print sysroot)/lib/rustlib/src/rust/library`.

CRATE=${1:-}
if [[ -z "$CRATE" ]]; then
    echo "Usage: $0 CRATE_NAME"
    exit 1
fi
shift

# compute the library directory (and export for Miri)
MIRI_LIB_SRC=${MIRI_LIB_SRC:-$(rustc --print sysroot)/lib/rustlib/src/rust/library}
if ! test -d "$MIRI_LIB_SRC/core"; then
    echo "Rust source dir ($MIRI_LIB_SRC) does not contain a 'core' subdirectory."
    echo "Set MIRI_LIB_SRC to the Rust source directory, or install the rust-src component."
    exit 1
fi
# macOS does not have a useful readlink/realpath so we have to use Python instead...
MIRI_LIB_SRC=$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$MIRI_LIB_SRC")
export MIRI_LIB_SRC

# update symlink
rm -f library
ln -s "$MIRI_LIB_SRC" library

# use the rust-src lockfile
cp "$MIRI_LIB_SRC/Cargo.lock" Cargo.lock

# This ensures that the "core" crate being built as part of `cargo miri test`
# is just a re-export of the sysroot crate, so we don't get duplicate lang items.
export MIRI_REPLACE_LIBRS_IF_NOT_TEST=1

# Set the right rustflags.
export RUSTFLAGS="${RUSTFLAGS:-} -Zforce-unstable-if-unmarked"
export RUSTDOCFLAGS="${RUSTDOCFLAGS:-} -Zforce-unstable-if-unmarked"

# run test
export CARGO_TARGET_DIR=$(pwd)/target
cargo miri test --manifest-path "library/$CRATE/Cargo.toml" "$@"
