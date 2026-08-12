/*
 * Workaround for LLVM 19+ requiring evex512 target feature for AVX-512 512-bit intrinsics.
 * See: https://github.com/ziglang/zig/issues/20414
 */
#ifndef MDBX_AVX512_FIX_H
#define MDBX_AVX512_FIX_H

#define MDBX_ATTRIBUTE_TARGET(target) __attribute__((__target__(target ",evex512")))

#endif /* MDBX_AVX512_FIX_H */
