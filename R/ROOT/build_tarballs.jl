# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "ROOT"
version = v"6.32.2"

# Collection of sources required to complete build
sources = [
    ArchiveSource("https://root.cern/download/root_v6.32.02.source.tar.gz", "3d0f76bf05857e1807ccfb2c9e014f525bcb625f94a2370b455f4b164961602d")
]

# Bash recipe for building across all platforms
script = raw"""

cd $WORKSPACE/srcdir
mkdir build && cd build
install_license ../root-*/LICENSE

# Common options/flags
CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=$prefix -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN}"

# Release type and C++ standard
CMAKE_FLAGS="${CMAKE_FLAGS}
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CXX_STANDARD=17
    "

# ROOT options to enable/disable
CMAKE_FLAGS="${CMAKE_FLAGS}
    -Dfail-on-missing=ON
    -Dminimal=ON
    "

# LLVM tries to run a bunch of configure tests. Tell it what the output would have been.
CMAKE_FLAGS="${CMAKE_FLAGS}
    -Dfound_urandom_EXITCODE=0
    -Dfound_urandom_EXITCODE__TRYRUN_OUTPUT=''
    "

cmake -G "Unix Makefiles" ${CMAKE_FLAGS} ../root-*/
make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms(exclude= p->libc(p) == "musl" || os(p) == "freebsd" || os(p) == "windows") |> expand_cxxstring_abis

# The products that we will ensure are always built
products = [
    LibraryProduct("libCore", :libCore),
    LibraryProduct("libCling", :libCling),
    ExecutableProduct("root", :root),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("Zlib_jll")
    Dependency("Zstd_jll")
    Dependency("Lz4_jll")
    Dependency("nlohmann_json_jll")
    Dependency("FreeType2_jll")
    Dependency("PCRE_jll")
    Dependency("XZ_jll")
    Dependency("xxHash_jll")
    Dependency("OpenSSL_jll"; compat="1.1.10")
    #Dependency("LLVM_jll"; compat="16.0")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               preferred_gcc_version=v"8", julia_compat="1.6")
