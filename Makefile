# C/C++ compiler
CXX=g++

# C++ files
CPP_SRC=intsort.cpp serial_sort.cpp tasksys.cpp

# ISPC files
ISPC_SRC=radix_sort.ispc merge_sort.ispc

# ISPC targets
ISPC_TARGETS=sse2,sse4,avx

# Program name
EXE=intsort

# Floating point type
REAL=double

# Debug version
DEBUG=no

# Do the rest
include common.mk
