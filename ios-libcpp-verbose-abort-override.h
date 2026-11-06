// ios-libcpp-verbose-abort-override.h — 覆盖 libc++ 的 _LIBCPP_VERBOSE_ABORT 宏
//
// 动机：Zig 0.16.0 自带 libc++ 21 对 iOS <16 目标错误地把
// `_LIBCPP_AVAILABILITY_HAS_VERBOSE_ABORT` 判为真（__configuration/availability.h
// 里恒 = `_LIBCPP_INTRODUCED_IN_LLVM_15`），使 `-fno-exceptions` 下的
// std::vector::push_back 等路径（如 crypto/x509/by_dir.cc 的 Vector::Push）引用
// iOS 16+ 才由 /usr/lib/libc++.1.dylib 导出的 `__libcpp_verbose_abort` —— iOS 15
// dyld 报 Symbol missing 启动即崩。
//
// 本头覆盖 libc++ 文档明示的用户自定义点 `_LIBCPP_VERBOSE_ABORT`（__verbose_abort
// 里 `#if !defined(_LIBCPP_VERBOSE_ABORT)` 才给默认值），让回退走 iOS 15 就有的
// `__builtin_abort()`，不再依赖该符号。代价：这条「本应崩溃」的路径上丢掉诊断
// 消息（静默 abort），只影响崩溃现场的可读性，不影响任何正常路径。
//
// ⚠️ 必须经 `-include` 强制在任何 libc++ 头之前注入（见 build.zig 的 bs_configure，
// 仅 iOS 目标挂此头）。
#define _LIBCPP_VERBOSE_ABORT(...) __builtin_abort()
