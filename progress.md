# Progress Log — zigprebuild

## 2026-08-12: v0.24.0 — 新增 lwIP、libmdbx、lmdbx-zig、cpu_model submodule ✅

- **Status:** complete
- 从 `zigproxy/vendor/` 迁移 libmdbx、lmdbx-zig、cpu_features → cpu_model 至 zigprebuild
  - libmdbx: `Mithril-mine/libmdbx` v0.14.2（之前为裸拷文件）
  - lmdbx-zig: fork 自 `theseyan/lmdbx-zig` v0.4.0 → `fixnet-ai/lmdbx-zig` v0.4.1（新增 FreeBSD 构建修复、path-based deps）
  - cpu_model: `slyshykO/cpu_model` main（LLVM compiler-rt cpu_model 子集，替代原 cpu_features）
- 从 `zigtun/src/lwip` 迁移 lwIP 至 zigprebuild
  - lwIP: fork 自 `lwip-tcpip/lwip` STABLE-2.2.1 → `fixnet-ai/lwip` STABLE-2_2_1-fixnet（含 fixnet port + PRETEND 透明代理补丁）
- 消费项目路径更新：
  - zigfoundation `build.zig.zon`: `.lmdbx` → `../zigprebuild/lmdbx-zig`
  - zproxy `build.zig.zon`: `.lmdbx` → `../zigprebuild/lmdbx-zig`
  - zigtun `build.zig`: lwIP 改用 `prebuild_dep.path("lwip/...")`
- 删除 `zigproxy/vendor/` 和 `zproxy/vendor/` 中的冗余副本
- 验证：6/6 平台全通过（含 FreeBSD）

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
