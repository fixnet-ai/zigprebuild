# Progress Log — zigprebuild

## 2026-08-09: v0.23.0 — 项目初始化 ✅

- **Status:** complete
- 创建 zigprebuild 项目，统一管理 fixnet 生态所有 C 库的跨平台预编译
- 添加 4 个 git submodule（均指向正式 release tag）：
  - boringssl: google/boringssl main (922245a)
  - nghttp2: v1.70.0
  - ngtcp2: v1.25.0
  - nghttp3: v1.18.0
- 添加 libyaml submodule (v0.2.5) 及 yaml_c Zig 模块
- 统一 build.zig：cmake + zig cc 交叉编译重量库，Zig 原生编译轻量库
- 构建隔离：不同 target 使用独立 cmake build 目录
- 验证：aarch64-macos-none + aarch64-linux-musl 双平台通过

### 消费项目迁移

- **zigoutbounds**: 删除 ~200 行 cmake 构建代码 → 纯链接 zigprebuild 产物
- **zigbox**: boringssl → zigprebuild
- **zigfoundation**: vendor/yaml/ 删除（-15265 行 C 源码）→ prebuild_dep.module("yaml_c")

### 清理

- 删除旧 `../boringssl` 项目
- 删除旧 `vendor/ngtcp2`、`vendor/nghttp3` 源码目录
