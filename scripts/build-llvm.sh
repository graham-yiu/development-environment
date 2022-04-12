#!/bin/bash -e

llvm_source_dir=$PWD/llvm
clang_source_dir=$PWD/clang
build_dir=$PWD/build
install_dir=$HOME
build_c_compiler=/usr/bin/gcc
build_cxx_compiler=/usr/bin/g++
# May need these if OS has old GLIBC/GLIBCXX installed
rt_search_paths="\
  /usr/lib \
  /usr/lib64 \
"

if [ ! -d $llvm_source_dir ]; then
  echo "ERROR: Can't find source dir $llvm_source_dir"
  exit 1
fi

if [ ! -d $build_dir ]; then
  mkdir $build_dir
fi

export PATH=$HOME/bin:${PATH}

# Add runtime library search paths
for path in $rt_search_paths; do
  link_options="$link_options -Wl,-rpath,$path" 
  # cmake requires newer level of GLIBCXX
  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:$path
done

set -x
# Run cmake
# Options
# -DCMAKE_BUILD_TYPE=[Release|Debug|RelWithDebInfo]
# -DCMAKE_CXX_FLAGS_RELWITHDEBINFO=[-O2|-O0]
# -DLLVM_ENABLE_ASSERTIONS=[ON|OFF]
# -DLLVM_ENABLE_PROJECTS=[clang|lld|compiler-rt|...]
cd $build_dir
cmake $llvm_source_dir -G Ninja \
  -DCMAKE_CXX_LINK_FLAGS="$link_options " \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS=clang \
  -DCMAKE_C_COMPILER=$build_c_compiler \
  -DCMAKE_CXX_COMPILER=$build_cxx_compiler \
  -DCMAKE_INSTALL_PREFIX=$install_dir \
  >cmake.log 2>&1

# Build
smartninja 2>&1 | tee ninja.log
set +x
