# brotli（decode-only 子集）

google/brotli **v1.1.0** 的**解码侧最小子集**，vendor 进本仓供 BoringSSL
TLS 证书压缩（RFC 8879 `compress_certificate`，alg id 2 = brotli）客户端解压使用。

- 上游：https://github.com/google/brotli （tag v1.1.0，MIT，见 `LICENSE`）
- 未改动任何源码内容；仅做文件裁剪与目录归位。

## 为什么是 decode-only

zigbox 生态只消费 brotli **解压**（chrome/edge TLS 指纹通告
`compress_certificate(brotli)`，服务器发压缩证书时必须能解）。
编码侧（`c/enc/`）与工具（`c/tools/`）、测试不在依赖面内，按最小 vendor
原则裁掉；后续若出现编码需求再补。

## 文件清单（相对上游 `c/`）

| 本仓路径 | 上游路径 | 用途 |
|---|---|---|
| `include/brotli/{decode,port,shared_dictionary,types}.h` | `c/include/brotli/` | 公共头（`<brotli/decode.h>` 入口） |
| `common/*.c,h` | `c/common/`（同名单文件） | 常量/上下文/字典/平台/共享字典/transform |
| `dec/*.c,h` | `c/dec/`（同名单文件） | 位读取器/Huffman/状态机/decode 入口 |

裁剪说明：`c/common/` 全量保留（`dec/decode.c`、`dec/state.c` 经
`shared_dictionary_internal.h` 依赖 `shared_dictionary.c`）；`c/include/brotli/`
仅去掉 `encode.h`。

## 接入方式（build.zig）

`brotli_c` Zig 模块（`brotli_c.zig` 为绑定入口）+ `addCSourceFiles` 直接编译
10 个 .c（纯 C99，无外部依赖，zig cc 全平台可编，同 libyaml 先例——不走 cmake、
无预编译产物，消费者按 target 现编）。

```zig
const brotli_dep = b.dependency("zigprebuild", .{ .target = target, .optimize = optimize });
const brotli_mod = brotli_dep.module("brotli_c");
some_module.addImport("brotli_c", brotli_mod);
```

当前消费者：zigoutbounds（`src/crypto/boringssl.zig` 的
`certDecompress` 回调，注册进 `SSL_CTX_add_cert_compression_alg`）。

## 关键 API（decode.h）

```c
// 一次性解压：decoded_buffer 需调用方保证 ≥ 期望明文长度，
// *decoded_size 入参 = 缓冲容量，出参 = 实际明文长度。
BrotliDecoderResult BrotliDecoderDecompress(
    size_t encoded_size, const uint8_t *encoded_buffer,
    size_t *decoded_size, uint8_t *decoded_buffer);
```

`BrotliDecoderResult`：0=ERROR，1=SUCCESS，2=NEEDS_MORE_OUTPUT，3=NEEDS_MORE_INPUT。
