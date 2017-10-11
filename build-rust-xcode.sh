#!/bin/bash

# When building from Xcode we want to ensure that `cargo` is in PATH.
# as a convenience, add the default cargo install location
export PATH="$PATH:${HOME}/.cargo/bin"

# Users can optionally set cargo path in xi-mac/.env
if [[ -f "${SRCROOT}/.env" ]]; then
    source "${SRCROOT}/.env"
    if ! [[ -z "$CARGO_PATH" ]]; then
        export PATH="$CARGO_PATH:$PATH"
    else
        echo "warning: ${SRCROOT}/.env file found, but CARGO_PATH not set."
    fi
fi

if ! [[ -x "$(command -v cargo)" ]]; then
    echo 'error: Unable to find cargo command. If cargo is not installed visit rustup.rs, otherwise set CARGO_PATH in xi-mac/.env' >&2
    exit 127
fi

set -e

function build_target () {
    TARGET_NAME="$1"
    cd "${SRCROOT}/xi-editor/$2"
    if [[ ${ACTION:-build} = "build" ]]; then
        if [[ $PLATFORM_NAME = "" ]]; then
            # default for building with xcodebuild
            PLATFORM_NAME="macosx"
        fi

        if [[ $PLATFORM_NAME = "macosx" ]]; then
            RUST_TARGET_OS="darwin"
        else
            RUST_TARGET_OS="ios"
        fi

        for ARCH in $ARCHS
        do
            if [[ $(lipo -info "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}" 2>&1) != *"${ARCH}"* ]]; then
                rm -f "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}"
            fi
        done

        if [[ $CONFIGURATION = "Debug" ]]; then
            RUST_CONFIGURATION="debug"
            RUST_CONFIGURATION_FLAG=""
        else
            RUST_CONFIGURATION="release"
            RUST_CONFIGURATION_FLAG="--release"
        fi

        EXECUTABLES=()
        for ARCH in $ARCHS
        do
            RUST_ARCH=$ARCH
            if [[ $RUST_ARCH = "arm64" ]]; then
                RUST_ARCH="aarch64"
            fi
            cargo build $RUST_CONFIGURATION_FLAG --target "${RUST_ARCH}-apple-${RUST_TARGET_OS}"
            EXECUTABLES+=("target/${RUST_ARCH}-apple-${RUST_TARGET_OS}/${RUST_CONFIGURATION}/${TARGET_NAME}")
        done

        mkdir -p "${BUILT_PRODUCTS_DIR}"
        xcrun --sdk $PLATFORM_NAME lipo -create "${EXECUTABLES[@]}" -output "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}"
    elif [[ $ACTION = "clean" ]]; then
        cargo clean
        rm -f "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}"
    fi
}

build_target xi-core rust
build_target xi-syntect-plugin rust/syntect-plugin

# move syntect plugin into plugins dir
mkdir -p "${BUILT_PRODUCTS_DIR}/plugins/syntect/bin"
mv "${BUILT_PRODUCTS_DIR}/xi-syntect-plugin" "${BUILT_PRODUCTS_DIR}/plugins/syntect/bin/"
cp "${SRCROOT}/xi-editor/rust/syntect-plugin/manifest.toml" "${BUILT_PRODUCTS_DIR}/plugins/syntect/"

# workaround for https://github.com/travis-ci/travis-ci/issues/6522
set +e
