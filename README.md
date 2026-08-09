# zigprebuild

跨平台 C 静态库预编译项目。通过 cmake + zig cc（或 Zig 原生编译）将
BoringSSL、nghttp2、ngtcp2、nghttp3、libyaml 从官方 release 源码交叉编译，
供 zigbox 生态各项目直接链接使用。

## 设计目标

- **一次构建，多处复用** — 消费项目只链接预编译 `.a` 文件，不运行 cmake
- **版本锁定** — 通过 git submodule 指向各库的正式 release tag，构建可复现
- **跨平台** — 同一套构建逻辑产出 macOS / Linux / Windows 多平台产物

## 包含的库

| 库 | 版本 | 用途 | 依赖 |
|---|------|------|------|
| [BoringSSL](https://github.com/google/boringssl) | main (922245a) | TLS/加密 | — |
| [nghttp2](https://github.com/nghttp2/nghttp2) | v1.70.0 | HTTP/2 帧层 | — |
| [ngtcp2](https://github.com/ngtcp2/ngtcp2) | v1.25.0 | QUIC 传输层 | BoringSSL |
| [nghttp3](https://github.com/ngtcp2/nghttp3) | v1.18.0 | HTTP/3 帧层 | — |
| [libyaml](https://github.com/yaml/libyaml) | v0.2.5 | YAML 解析 | — |

## 快速开始

### 构建

```bash
# 克隆（含子模块）
git clone --recurse-submodules https://github.com/fixnet-ai/zigprebuild.git
cd zigprebuild

# 本机平台
zig build

# 交叉编译
zig build -Dtarget=aarch64-linux-musl
zig build -Dtarget=x86_64-linux-musl
zig build -Dtarget=x86_64-windows-gnu
```

### 产物结构

```
zig-out/<target>/
  lib/
    libssl.a                       # BoringSSL SSL
    libcrypto.a                    # BoringSSL 加密
    libnghttp2.a                   # HTTP/2
    libngtcp2.a                    # QUIC 传输
    libngtcp2_crypto_boringssl.a   # ngtcp2 BoringSSL 后端
    libnghttp3.a                   # HTTP/3
  include/
    openssl/                       # BoringSSL 头文件
    nghttp2/                       # nghttp2 头文件
    ngtcp2/                        # ngtcp2 头文件
    nghttp3/                       # nghttp3 头文件
```

libyaml（轻量库）通过 Zig 模块暴露，无独立 `.a` 文件（通过 `addCSourceFiles` 嵌入消费模块）。

### 在消费项目中使用

**重量库（.a 文件）：**

`build.zig.zon`:

```zig
.zigprebuild = .{
    .path = "../zigprebuild",
},
```

`build.zig`:

```zig
const prebuild_dep = b.dependency("zigprebuild", .{
    .target = target,
    .optimize = optimize,
});
const out = b.fmt("zig-out/{s}", .{zig_target});

module.addObjectFile(prebuild_dep.path(b.fmt("{s}/lib/libssl.a", .{out})));
module.addObjectFile(prebuild_dep.path(b.fmt("{s}/lib/libcrypto.a", .{out})));
module.addIncludePath(prebuild_dep.path(b.fmt("{s}/include", .{out})));
```

**轻量库（Zig 模块）：**

```zig
module.addImport("yaml_c", prebuild_dep.module("yaml_c"));
```

## 构建依赖

- Zig 0.16.0+
- cmake + Ninja

## 更新子模块

```bash
# 更新到最新 release
cd ngtcp2 && git fetch --tags && git checkout v<new_version> && cd ..
git add ngtcp2 && git commit -m "chore: update ngtcp2 to v<new_version>"
```

## 许可

各子模块遵循其原始许可协议。本项目构建脚本（build.zig）采用 MIT License。
