//! brotli 解码器 Zig 绑定入口（decode-only 子集，v1.1.0）。
//!
//! C 源码（common/ + dec/）由 zigprebuild 的 build.zig 以 addCSourceFiles
//! 挂到本模块（libyaml 先例：不走 cmake、无预编译产物，消费者按 target 现编）。
//! 消费者 addImport("brotli_c", ...) 即随模块图参与编译与链接。
//!
//! 当前唯一消费方：zigoutbounds src/crypto/boringssl.zig 的证书压缩解压回调
//! （RFC 8879 compress_certificate，chrome/edge 指纹）。

/// BrotliDecoderResult（brotli/types.h）：解压一次性 API 的返回码。
pub const Result = enum(c_int) {
    error_occurred = 0, // BROTLI_DECODER_RESULT_ERROR
    success = 1, // BROTLI_DECODER_RESULT_SUCCESS
    needs_more_output = 2, // BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT
    needs_more_input = 3, // BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT
    _,
};

/// 一次性解压（decode.h 的 BrotliDecoderDecompress）。
///
/// - `encoded_size`/`encoded_buffer`：压缩输入；
/// - `decoded_size`：入参 = `decoded_buffer` 容量，出参 = 实际明文长度；
/// - `decoded_buffer`：调用方提供的输出缓冲，须 ≥ 期望明文长度。
pub extern "c" fn BrotliDecoderDecompress(
    encoded_size: usize,
    encoded_buffer: [*]const u8,
    decoded_size: *usize,
    decoded_buffer: [*]u8,
) Result;

test {
    _ = @import("brotli_c_test.zig");
}
