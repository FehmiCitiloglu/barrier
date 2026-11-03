#!/bin/sh
cd "$(dirname "$0")" || exit 1
# some environments have cmake v2 as 'cmake' and v3 as 'cmake3'
# check for cmake3 first then fallback to just cmake
B_CMAKE=`type cmake3 2>/dev/null`
if [ $? -eq 0 ]; then
    B_CMAKE=`echo "$B_CMAKE" | cut -d' ' -f3`
else
    B_CMAKE=cmake
fi
# default build configuration
B_BUILD_TYPE=${B_BUILD_TYPE:-Debug}
if [ "$(uname)" = "Darwin" ]; then
    # OSX needs a lot of extra help, poor thing
    # run the osx_environment.sh script to fix paths
    . ./osx_environment.sh || exit 1
    [ -n "${CMAKE_OSX_ARCHITECTURES:-}" ] && B_CMAKE_FLAGS="-DCMAKE_OSX_ARCHITECTURES=$CMAKE_OSX_ARCHITECTURES $B_CMAKE_FLAGS"
    [ -n "${CMAKE_OSX_DEPLOYMENT_TARGET:-}" ] && B_CMAKE_FLAGS="-DCMAKE_OSX_DEPLOYMENT_TARGET=$CMAKE_OSX_DEPLOYMENT_TARGET $B_CMAKE_FLAGS"
    [ -n "${CMAKE_PREFIX_PATH:-}" ] && B_CMAKE_FLAGS="-DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH $B_CMAKE_FLAGS"
    [ -n "${OPENSSL_ROOT_DIR:-}" ] && B_CMAKE_FLAGS="-DOPENSSL_ROOT_DIR=$OPENSSL_ROOT_DIR $B_CMAKE_FLAGS"
fi
# allow local customizations to build environment
[ -r ./build_env.sh ] && . ./build_env.sh

# Initialise Git submodules
git submodule update --init --recursive

B_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=$B_BUILD_TYPE $B_CMAKE_FLAGS"
rm -rf build
mkdir build || exit 1
cd build || exit 1
echo "Starting Barrier $B_BUILD_TYPE build..."
$B_CMAKE $B_CMAKE_FLAGS .. || exit 1
$B_CMAKE --build . --parallel || exit 1
echo "Build completed successfully"
