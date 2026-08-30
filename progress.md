# Progress Log — zigprebuild

> 瘦身注记（第 4 轮，2026-08-27）：本文件仅存「历史完成阶段总表 + 基线数字 + 决策定论」，
> 无待办任务；技术细节已迁 build.zig 代码注释与 zigfoundation/zig-codegen.md（指针见 v0.25.0 条目）。
> 项目无 task_plan.md / findings.md（无待办、无研究任务），仅此一个规划文件。

> C 库预编译管理，无待办任务；统一规划见 zigbox task_plan.md『跨项目统一待办』。

## 版本完成总表

| 版本 | 日期 | 内容 |
|------|------|------|
| v0.25.0 | 2026-08-18 | 新增 Android / iOS 预编译支持 |
| v0.24.0 | 2026-08-12 | 新增 lwIP / libmdbx / lmdbx-zig / cpu_model submodule |
| v0.23.0 | 2026-08-09 | 项目初始化 |

## 最新改动（未发 tag）— BoringSSL 启用汇编加速（2026-08-30，zigbox #120/#121/#122）

- **背景**：原 `-DOPENSSL_NO_ASM=ON` 无条件启用 → 全部平台纯 C 编译（AES-NI/aesv8/ghash-neon/ChaCha20_neon 全禁），TLS/QUIC 加密走 C 路径。根因 = build.zig 只设 CC/CXX，未设 `CMAKE_ASM_COMPILER` → CMake 落回宿主 as 交叉失败。
- **改动（build.zig）**：
  1. `setup_wrappers` 生成 `build/wrappers/zig-asm`（`exec zig cc -target <target> "$@"`）——zig cc 集成汇编器原生支持 `.S` 预处理+汇编，3 平台 44 文件实测 0 失败。
  2. configure 参数化 `asm_arg`：非 Windows x86_64 → `-DCMAKE_ASM_COMPILER=<zig-asm>`（boringssl 顶层 CMakeLists `enable_language(ASM)` + include_directories 自动附加）；Windows x86/x86_64 → 保留 `-DOPENSSL_NO_ASM=ON`（.asm 需 NASM）；aarch64-windows 走 ASM 不受影响。
- **产物验证（aarch64-macos）**：CMakeCache `CMAKE_ASM_COMPILER_WORKS=1` + `aesv8-armv8-apple`/`ghash-neon-armv8-apple`/`ghashv8-armv8-apple`/`bn-armv8-apple`/`p256-armv8-asm-apple` 全部编译进 fipsmodule + nm 确认 `_ChaCha20_ctr32_neon`/`_gcm_init_v8`/`_gcm_ghash_v8`/`_gcm_ghash_neon`/`_vpaes_*` 全定义。
- **性能收益**（重编 zigoutbounds 后协议级 bench-tcp，CPU 满载=每字节成本受限）：trojan +10.3% / anytls +6.8% / vless-reality +5.5% / hysteria2 +6.0% / tuic +13.1%；对照 vless（纯 TCP 无加密）-0.8% 噪声内无变化 = 无副作用。全 PASS 无回归。完整报表 zigbox `pref-2026-08-30-boringssl-asm.md`。
- **经验（Zig 0.16）**：`std.ArrayList([]const u8)` 是 unmanaged（`array_list.Aligned(...,null)`）无 `init(gpa)`；b.fmt 是 Zig fmt 非 printf（`{s}` 非 `%s`）——build.zig 参数数组改用 if 表达式单值，勿用 ArrayList 拼接。

## v0.25.0 — 新增 Android / iOS 预编译支持 ✅

- release.sh TARGETS 6 → 10：`aarch64/x86_64-linux-android`、`aarch64-ios-none`、`aarch64-ios-simulator`
- 验证：4 新平台 BoringSSL/nghttp2/ngtcp2/nghttp3 全部编译通过，产物架构正确（ELF aarch64/x86_64、Mach-O arm64）
- 技术要点（已落 build.zig 代码注释：libc 头文件 :47-61、cmake 平台映射 :21-28、三元组 :36-42、BoringSSL 交叉标志 :119-122；Zig 层通用经验 → zig-codegen.md §10 交叉编译）：
  - iOS / Android 目标 zig 0.16.0 **不自动提供 libc 头文件**，需在 `CC`/`CXX` 环境变量手动补 `-isystem`
  - iOS → zig 内置 darwin libc `libc/include/any-darwin-any`（与 macOS 同源）；Android → NDK sysroot Bionic 头文件
  - cmake 映射：iOS 用 `CMAKE_SYSTEM_NAME=iOS`，Android 用 `Linux`（避免 NDK 查找报错）
  - BoringSSL 统一 `-DBUILD_TESTING=OFF`（跳过 benchmark 的 regex 检测，交叉编译必现失败）+ `-DCMAKE_MACOSX_BUNDLE=OFF`
  - `findNdkSysroot()` 从 `ANDROID_NDK_HOME` 遍历 `toolchains/llvm/prebuilt/` 定位 sysroot；`zig_target` 用 `@tagName(abi)` 统一生成三元组

## v0.24.0 — 新增 lwIP / libmdbx / lmdbx-zig / cpu_model submodule ✅

- 从 `zigproxy/vendor/`、`zigtun/src/lwip` 迁移至 zigprebuild：
  - libmdbx: `Mithril-mine/libmdbx` v0.14.2（原为裸拷文件）
  - lmdbx-zig: fork 自 `theseyan/lmdbx-zig` v0.4.0 → `fixnet-ai/lmdbx-zig` v0.4.1（新增 FreeBSD 构建修复、path-based deps）
  - cpu_model: `slyshykO/cpu_model` main（LLVM compiler-rt cpu_model 子集，替代原 cpu_features）
  - lwIP: fork 自 `lwip-tcpip/lwip` STABLE-2.2.1 → `fixnet-ai/lwip` STABLE-2_2_1-fixnet（含 fixnet port + PRETEND 透明代理补丁）
- 消费项目路径更新：zigfoundation / zproxy `build.zig.zon` `.lmdbx` → `../zigprebuild/lmdbx-zig`；zigtun `build.zig` lwIP 改用 `prebuild_dep.path("lwip/...")`
- 删除 `zigproxy/vendor/`、`zproxy/vendor/` 中的冗余副本；验证 6/6 平台全通过（含 FreeBSD）

## v0.23.0 — 项目初始化 ✅

- 创建 zigprebuild，统一管理 fixnet 生态所有 C 库的跨平台预编译；git submodule 均指向正式 release tag
- 初始 4 submodule：boringssl main (922245a)、nghttp2 v1.70.0、ngtcp2 v1.25.0、nghttp3 v1.18.0；libyaml v0.2.5 + yaml_c Zig 模块
- build.zig：cmake + zig cc 交叉编译重量库，Zig 原生编译轻量库；不同 target 使用独立 cmake build 目录
- 验证：aarch64-macos-none + aarch64-linux-musl 双平台通过

### 消费项目迁移

- **zigoutbounds**: 删除 ~200 行 cmake 构建代码 → 纯链接 zigprebuild 产物
- **zigbox**: boringssl → zigprebuild
- **zigfoundation**: vendor/yaml/ 删除（-15265 行 C 源码）→ prebuild_dep.module("yaml_c")

### 清理

- 删除旧 `../boringssl` 项目；删除旧 `vendor/ngtcp2`、`vendor/nghttp3` 源码目录
