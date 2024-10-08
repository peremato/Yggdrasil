# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

# See https://github.com/JuliaLang/Pkg.jl/issues/2942
# Once this Pkg issue is resolved, this must be removed
uuid = Base.UUID("a83860b7-747b-57cf-bf1f-3e79990d037f")
delete!(Pkg.Types.get_last_stdlibs(v"1.6.3"), uuid)

# needed for libjulia_platforms and julia_versions
include("../../L/libjulia/common.jl")

name = "libcxxwrap_julia"
version = v"0.13.2"

git_repo = "https://github.com/JuliaInterop/libcxxwrap-julia.git"

# Collection of sources required to complete build
sources = [
    GitSource(git_repo, "20eaeb785dcd18bd19ae3b029e0349f12f88a05a"),
    ArchiveSource("https://github.com/roblabla/MacOSX-SDKs/releases/download/13.3/MacOSX13.3.sdk.tar.xz",
    "e5d0f958a079106234b3a840f93653308a76d3dcea02d3aa8f2841f8df33050c")
]

# Bash recipe for building across all platforms
script = raw"""
mkdir build
cd build

if [[ "${target}" == *-apple-darwin* ]]; then
    # Install a newer SDK which supports `ranges`
    pushd $WORKSPACE/srcdir/MacOSX13.*.sdk
    rm -rf /opt/${target}/${target}/sys-root/System
    cp -ra usr/* "/opt/${target}/${target}/sys-root/usr/."
    cp -ra System "/opt/${target}/${target}/sys-root/."
    export MACOSX_DEPLOYMENT_TARGET=11
    popd
fi

cmake \
    -DJulia_PREFIX=$prefix \
    -DCMAKE_INSTALL_PREFIX=$prefix \
    -DCMAKE_FIND_ROOT_PATH=$prefix \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_BUILD_TYPE=Release \
    ../libcxxwrap-julia/

VERBOSE=ON cmake --build . --config Release --target install -- -j${nproc}
install_license $WORKSPACE/srcdir/libcxxwrap-julia*/LICENSE.md
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = vcat(libjulia_platforms.(julia_versions)...)
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = [
    LibraryProduct("libcxxwrap_julia", :libcxxwrap_julia; dlopen_flags=[:RTLD_GLOBAL]),
    LibraryProduct("libcxxwrap_julia_stl", :libcxxwrap_julia_stl; dlopen_flags=[:RTLD_GLOBAL]),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    BuildDependency(PackageSpec(;name="libjulia_jll", version=v"1.10.10")),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version = v"10", julia_compat = "1.6")
