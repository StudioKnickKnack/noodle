#!/usr/bin/env bash

# NOTE: this is a recent addition to the Odin compiler, if you don't have this command
# you can change this to the path to the Odin folder that contains vendor, eg: "~/Odin".
ROOT=$(odin root)
PROJECT=$(dirname "$0")
if [ ! $? -eq 0 ]; then
    echo "Your Odin compiler does not have the 'odin root' command, please update or hardcode it in the script."
    exit 1
fi

set -eu

# Figure out the mess that is dynamic libraries.
case $(uname) in
"Darwin")
    case $(uname -m) in
    "arm64") LIB_PATH="macos-arm64" ;;
    *)       LIB_PATH="macos" ;;
    esac

    SOKOL_DYLIB_DIR="$PROJECT/sokol/dylib"
    SOKOL_DYLIB_NAME="sokol_dylib_macos_arm64_metal_debug.dylib"
    install_name_tool -id @loader_path/sokol/dylib/$SOKOL_DYLIB_NAME $SOKOL_DYLIB_DIR/$SOKOL_DYLIB_NAME
    cp $SOKOL_DYLIB_DIR/$SOKOL_DYLIB_NAME $SOKOL_DYLIB_NAME

    DLL_EXT=".dylib"
    EXTRA_LINKER_FLAGS="-v -Wl,-rpath $ROOT/vendor/raylib/$LIB_PATH"
    #EXTRA_LINKER_FLAGS="$EXTRA_LINKER_FLAGS -Wl,$SOKOL_DIR/app/sokol_app$SOKOL_LIB_SUFFIX"


    ;;
*)
    DLL_EXT=".so"
    EXTRA_LINKER_FLAGS="'-Wl,-rpath=\$ORIGIN/linux'"

    # Copy the linux libraries into the project automatically.
    if [ ! -d "linux" ]; then
        mkdir linux
        cp -r $ROOT/vendor/raylib/linux/libraylib*.so* linux
    fi
    ;;
esac

# Build the app.
echo "Building app$DLL_EXT"
odin build app -define:SOKOL_DLL=true --extra-linker-flags:"$EXTRA_LINKER_FLAGS" -define:RAYLIB_SHARED=true -build-mode:dll -out:app_tmp$DLL_EXT -strict-style -vet -debug

# Need to use a temp file on Linux because it first writes an empty `app.so`, which the app will load before it is actually fully written.
mv app_tmp$DLL_EXT app$DLL_EXT

# Do not build the app_hot_reload.bin if it is already running.
# -f is there to make sure we match against full name, including .bin
if pgrep -fl 'app_hot_reload.bin' | grep -v 'lldb' > /dev/null; then
    echo "App running, hot reloading..."
    exit 1
else
    echo "Building app_hot_reload.bin"
    odin build main_hot_reload -define:SOKOL_DLL=true -extra-linker-flags:"-v" -out:app_hot_reload.bin -strict-style -vet -debug
fi
