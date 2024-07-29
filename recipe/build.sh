#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == "linux-ppc64le" ]]; then
  export CFLAGS="${CFLAGS//-fno-plt/}"
  export CXXFLAGS="${CXXFLAGS//-fno-plt/}"
fi

IS_PYPY=$(${PYTHON} -c "import platform; print(int(platform.python_implementation() == 'PyPy'))")
LIB_PYTHON="${PREFIX}/lib/libpython${PY_VER}${SHLIB_EXT}"
if [[ ${IS_PYPY} == "1" ]]; then
    INC_PYTHON="$PREFIX/include/pypy${PY_VER}"
else
    INC_PYTHON="$PREFIX/include/python${PY_VER}"
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  CMAKE_ARGS="${CMAKE_ARGS} -DLLVM_TABLEGEN_EXE=$BUILD_PREFIX/bin/llvm-tblgen -DNATIVE_LLVM_DIR=$BUILD_PREFIX/lib/cmake/llvm"
  CMAKE_ARGS="${CMAKE_ARGS} -DCROSS_TOOLCHAIN_FLAGS_NATIVE=-DCMAKE_C_COMPILER=$CC_FOR_BUILD;-DCMAKE_CXX_COMPILER=$CXX_FOR_BUILD;-DCMAKE_C_FLAGS=-O2;-DCMAKE_CXX_FLAGS=-O2;-DCMAKE_EXE_LINKER_FLAGS=\"-L$BUILD_PREFIX/lib\";-DCMAKE_MODULE_LINKER_FLAGS=;-DCMAKE_SHARED_LINKER_FLAGS=;-DCMAKE_STATIC_LINKER_FLAGS=;-DCMAKE_AR=$(which ${AR});-DCMAKE_RANLIB=$(which ${RANLIB});-DZLIB_ROOT=${BUILD_PREFIX}"
else
  rm -rf $BUILD_PREFIX/bin/llvm-tblgen
fi

mkdir -p build
cd build

cmake ${CMAKE_ARGS} \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_BUILD_TOOLS=ON \
  -DLLVM_BUILD_UTILS=ON \
  -DMLIR_ENABLE_BINDINGS_PYTHON:bool=ON \
  -DCMAKE_SKIP_RPATH:bool=ON \
  -DPYTHON_PACKAGES_PATH=${SP_DIR} \
  -DPYTHON_EXECUTABLE=${PYTHON} \
  -DPYTHON_INCLUDE_DIR=${INC_PYTHON} \
  -DPYTHON_LIBRARY=${LIB_PYTHON} \
  -DPYTHON3_EXECUTABLE=${PYTHON} \
  -DPYTHON3_INCLUDE_DIR=${INC_PYTHON} \
  -DPYTHON3_NUMPY_INCLUDE_DIRS=$(python -c 'import numpy;print(numpy.get_include())')  \
  -DPYTHON3_LIBRARY=${LIB_PYTHON} \
  -DPYTHON3_PACKAGES_PATH=${SP_DIR} \
  -DPYTHON2_EXECUTABLE= \
  -DPYTHON2_INCLUDE_DIR= \
  -DPYTHON2_NUMPY_INCLUDE_DIRS= \
  -DPYTHON2_LIBRARY= \
  -DPYTHON2_PACKAGES_PATH= \
  -DOPENCV_PYTHON2_INSTALL_PATH= \
  -GNinja \
  ../mlir

ninja
ninja install

cd $PREFIX

mkdir -p $SP_DIR
mv $PREFIX/python_packages/mlir_core/mlir $SP_DIR/

rm -rf $PREFIX/src $PREFIX/python_packages
