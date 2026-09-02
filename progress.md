# Progress Log — zigprebuild

> v0.33.0 里程碑瘦身：本文件仅存「历史完成总表 + 当前基线 + 决策定论」，无待办任务；
> 技术细节已迁 build.zig 代码注释与 zigfoundation/zig-codegen.md。项目无 task_plan/findings.md；
> 统一待办见 zigbox task_plan.md『跨项目统一待办』。

## 版本完成总表

| 版本 | 日期 | 内容 |
|------|------|------|
| v0.34.0 | 2026-09-02 | 11 仓统一里程碑 tag（本仓 v0.33.0 后仅 2 lwip 子模块纯指针 bump，无 patch tag；明细见下方「决策定论」） |
| v0.33.0 | 2026-09-01 | 里程碑整理（tag 已切 a0dbcf8，含 BoringSSL 汇编加速） |
| v0.25.0 | 2026-08-18 | Android / iOS 预编译支持（技术要点已落 build.zig 注释） |
| v0.24.0 | 2026-08-12 | lwIP / libmdbx / lmdbx-zig / cpu_model submodule 迁移 |
| v0.23.0 | 2026-08-09 | 项目初始化（4 submodule + libyaml/yaml_c） |

## 当前基线 — BoringSSL 汇编加速已闭环（zigbox #120-#122，v0.33.0 已发布）

- 全线汇编（build.zig 注释：setup_wrappers zig-asm :71-76、ASM 参数 :118-124/:149-152、
  findNasm :411-413）：非 Windows → `CMAKE_ASM_COMPILER=zig-asm` 编 .S（3 平台 44 文件 0 失败）；
  Windows x86/x86_64 → NASM 交叉汇编（有 → ASM，无 → 降级 NO_ASM + 告警）；两分支显式
  `-DOPENSSL_NO_ASM=OFF` 防增量 CMakeCache 残留（#122 实测 315 单元无 ASM_NASM 行）。
- aarch64-macos 产物验证：aesv8/ghash-neon/bn-armv8 全进 fipsmodule；协议级收益（CPU 满载）
  tuic +13.1% / trojan +10.3% / anytls +6.8% / hy2 +6.0% / vless-reality +5.5%，vless -0.8% 噪声内，
  全 PASS 无回归（报表 zigbox `pref-2026-08-30-boringssl-asm.md`）。
- Windows x86_64-windows-gnu 已重编（315 单元含全部 -win.asm，nm 88 个 ASM 符号）；数值收益待 windowsvm bench。
- Zig 0.16 经验（unmanaged ArrayList / b.fmt 非 printf）→ zig-codegen.md。

## 决策定论 — lwIP 版本释放（#20，2026-09-02）

- **完成态（v0.34.0）**：11 仓统一里程碑 tag；本仓 v0.33.0 后仅 2 lwip 子模块纯指针 bump
  （a899a14 → cd779790 netif MTU/ipaddr wrapper（MASQUE no-tun P4）/ f02dc17 → 367acee
  lwip_compat.c）。消费方本地编译即时消费，无需独立 patch tag，随本里程碑统一覆盖。
- **判断依据**：lwip 由消费方（zf/zo/zt/zigbox）从本仓工作树直接编译 C 源（build.zig.zon
  .paths 注释）——无预编译产物差异、消费方路径依赖不按 tag pin → 工作树即时消费，
  无需为纯指针 bump 单发 patch tag（#20 明确释放判断，09-02）。
