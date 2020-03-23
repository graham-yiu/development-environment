#!/bin/bash
set -x

source_dir=$PWD/llvm
if [ ! -d $source_dir ]; then
  echo "ERROR: Can't find source dir $source_dir"
  exit 1
fi

build_dir="build"
if [ ! -d $build_dir ]; then
  mkdir $build_dir
fi

cd $build_dir
cmake $source_dir -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON >cmake.log 2>&1
rc=$?
echo RC=$rc
if [ $rc -ne 0 ]; then exit $rc; fi

smartninja >ninja.log 2>&1
rc=$?
echo RC=$rc
if [ $rc -ne 0 ]; then exit $rc; fi
