#!/bin/sh
# Explicit dependency selections take precedence over package-manager defaults.
if [ -z "${CMAKE_PREFIX_PATH:-}" ]; then
    if command -v brew >/dev/null 2>&1; then
        CMAKE_PREFIX_PATH=$(brew --prefix qt@5) || return 1
    elif command -v port >/dev/null 2>&1; then
        CMAKE_PREFIX_PATH=/opt/local/libexec/qt5
    else
        echo "Set CMAKE_PREFIX_PATH to a Qt 5 installation" >&2
        return 1
    fi
    export CMAKE_PREFIX_PATH
fi
if [ -z "${OPENSSL_ROOT_DIR:-}" ]; then
    if command -v brew >/dev/null 2>&1; then
        OPENSSL_ROOT_DIR=$(brew --prefix openssl@3) || return 1
    elif command -v port >/dev/null 2>&1; then
        OPENSSL_ROOT_DIR=/opt/local
    fi
    export OPENSSL_ROOT_DIR
fi
if [ -z "${CMAKE_OSX_ARCHITECTURES:-}" ]; then
    CMAKE_OSX_ARCHITECTURES=$(uname -m)
    export CMAKE_OSX_ARCHITECTURES
fi
if [ -z "${CMAKE_OSX_DEPLOYMENT_TARGET:-}" ]; then
    CMAKE_OSX_DEPLOYMENT_TARGET="$(sw_vers -productVersion | cut -d. -f1).0"
    export CMAKE_OSX_DEPLOYMENT_TARGET
fi
