//! brotli_c 模块自带往返单测（测试保障随交付走：库能力必须留库+自带测试）。
//!
//! 测试向量由 Node.js zlib.brotliCompressSync（quality 11）生成：明文 = 固定
//! 89 字节句子重复 6 次（534 字节，含长距 back-reference），密文 78 字节。

const std = @import("std");
const brotli = @import("brotli_c.zig");

/// 明文单句（89 字节；测试断言按 len == 89 校验，改句子须同步改断言）。
const sentence = "zigbox brotli cert decompression round trip vector — RFC 8879 compress_certificate — ";

/// 密文（78 字节，quality 11 全量压缩）。
const compressed = [_]u8{
    0x1b, 0x15, 0x02, 0xa0, 0x8d, 0xd4, 0x58, 0x4d,
    0xcc, 0xd5, 0x74, 0x9b, 0xd7, 0xbb, 0xe7, 0xd3,
    0xee, 0xa0, 0xe7, 0x0d, 0x34, 0x09, 0x21, 0x10,
    0x44, 0x22, 0x0a, 0x29, 0x70, 0xc8, 0x01, 0x7b,
    0x47, 0x6b, 0x1e, 0x07, 0x8e, 0x29, 0x04, 0x1e,
    0xb2, 0xd4, 0x6f, 0xc2, 0x0b, 0xdb, 0xef, 0x5b,
    0xe2, 0x41, 0x32, 0xea, 0x38, 0xd4, 0xb2, 0xb0,
    0x4c, 0x31, 0x07, 0x4a, 0x2e, 0x1d, 0xd7, 0xb4,
    0x22, 0xd7, 0x25, 0x47, 0x07, 0x33, 0x35, 0x24,
    0x7a, 0xea, 0x03, 0xfc, 0xae, 0x0f,
};

test "brotli decode 往返：534 字节明文（back-reference 密集）" {
    var plain: [6 * sentence.len]u8 = undefined;
    var i: usize = 0;
    while (i < plain.len) : (i += sentence.len) {
        @memcpy(plain[i .. i + sentence.len], sentence);
    }

    var out: [plain.len]u8 = undefined;
    var decoded_len: usize = out.len;
    const rc = brotli.BrotliDecoderDecompress(compressed.len, &compressed, &decoded_len, &out);
    try std.testing.expectEqual(brotli.Result.success, rc);
    try std.testing.expectEqual(plain.len, decoded_len);
    try std.testing.expectEqualSlices(u8, &plain, out[0..decoded_len]);
}

test "brotli decode 容量不足返回 error_occurred 不越界" {
    // 一次性 API 将一切非 SUCCESS 结果折叠为 ERROR（dec/decode.c:2283-2285），
    // 容量不足亦然——调用方必须先知道明文长度（TLS 证书压缩回调恰好已知）。
    var out: [16]u8 = undefined; // 远小于 534
    var decoded_len: usize = out.len;
    const rc = brotli.BrotliDecoderDecompress(compressed.len, &compressed, &decoded_len, &out);
    try std.testing.expectEqual(brotli.Result.error_occurred, rc);
}

test "brotli decode 坏流返回 error_occurred" {
    var bad = compressed;
    bad[4] ^= 0xff; // 破坏首块数据
    var out: [1024]u8 = undefined;
    var decoded_len: usize = out.len;
    const rc = brotli.BrotliDecoderDecompress(bad.len, &bad, &decoded_len, &out);
    try std.testing.expectEqual(brotli.Result.error_occurred, rc);
}
