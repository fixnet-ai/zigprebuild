//! brotli_c 模块自带往返单测（测试保障随交付走：库能力必须留库+自带测试）。
//!
//! 测试向量由 Node.js zlib.brotliCompressSync（quality 11）生成：明文 = 固定
//! 91 字节句子重复 6 次（546 字节，含长距 back-reference），密文 79 字节。

const std = @import("std");
const brotli = @import("brotli_c.zig");

/// 明文单句（91 字节；测试断言按 len == 91 校验，改句子须同步改断言）。
const sentence = "kisscore brotli cert decompression round trip vector — RFC 8879 compress_certificate — ";

/// 密文（79 字节，quality 11 全量压缩）。
const compressed = [_]u8{
    0x1b, 0x21, 0x02, 0xa0, 0x8c, 0xd4, 0x58, 0x4d,
    0xcc, 0xd5, 0x11, 0x2a, 0x5d, 0xdd, 0x96, 0xea,
    0x4a, 0xfb, 0xcd, 0x82, 0xa5, 0x0a, 0xde, 0x85,
    0xa3, 0x70, 0xb8, 0xc7, 0x90, 0x72, 0x8c, 0x03,
    0xf6, 0x17, 0x5c, 0xec, 0x7c, 0x1e, 0x18, 0x67,
    0xb8, 0x4c, 0xa7, 0xde, 0x74, 0x42, 0x25, 0x3a,
    0xfe, 0xfe, 0x3b, 0xae, 0x8c, 0xba, 0x0e, 0x63,
    0x16, 0x36, 0x67, 0xcb, 0x96, 0x48, 0x95, 0x7d,
    0x5a, 0x45, 0x3a, 0x93, 0xa3, 0x43, 0x55, 0x1a,
    0xc8, 0x9e, 0x21, 0x09, 0x3c, 0xd0, 0x0c,
};

test "brotli decode 往返：546 字节明文（back-reference 密集）" {
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
    var out: [16]u8 = undefined; // 远小于 546
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
