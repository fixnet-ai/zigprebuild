# Progress Log — zigprebuild

> C 库预编译管理，无待办任务；统一规划见 zigbox task_plan.md『跨项目统一待办』。

## 2026-08-18: v0.25.0 — 新增 Android / iOS 预编译支持 ✅

- **Status:** complete
- 新增 4 个 target，release.sh TARGETS 从 6 → 10：
  - `aarch64-linux-android`（arm64-v8a）、`x86_64-linux-android`（x86_64）
  - `aarch64-ios-none`（真机）、`aarch64-ios-simulator`（模拟器）
- 关键发现：zig 0.16.0 对 `.ios` 与 `.linux` + `.android`（Bionic）目标**不自动提供 libc 头文件**（`sys/types.h` 找不到），需在 `CC`/`CXX` 环境变量手动补 `-isystem`：
  - **iOS** → zig 内置 darwin libc 头文件 `libc/include/any-darwin-any`（与 macOS 同源；zig 对 `.ios` 不加该路径，期望外部 SDK）
  - **Android** → NDK sysroot 的 Bionic 头文件 `$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/<host>/sysroot/usr/include`（含 `<arch>-linux-android` 子目录）
- cmake 映射：iOS 用 `CMAKE_SYSTEM_NAME=iOS`，Android 用 `CMAKE_SYSTEM_NAME=Linux`（避免 NDK 查找报错）
- BoringSSL 统一加 `-DBUILD_TESTING=OFF`（跳过 benchmark 的 regex 检测，交叉编译必现失败）+ `-DCMAKE_MACOSX_BUNDLE=OFF`
- build.zig 新增 `findNdkSysroot()`（从 `ANDROID_NDK_HOME` 遍历 `toolchains/llvm/prebuilt/` 定位 sysroot）；`zig_target` 改用 `@tagName(abi)` 统一生成三元组
- 验证：4 个新平台 BoringSSL/nghttp2/ngtcp2/nghttp3 全部编译通过，产物架构正确（ELF aarch64/x86_64、Mach-O arm64）

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
