# Progress Log — zigprebuild

> v0.33.0 里程碑瘦身：本文件仅存「历史完成总表 + 当前基线 + 决策定论」，无待办任务；
> 技术细节已迁 build.zig 代码注释与 zigfoundation/zig-codegen.md。项目无 task_plan/findings.md；
> 统一待办见 zigbox task_plan.md『跨项目统一待办』。

## 版本完成总表

| 版本 | 日期 | 内容 |
|------|------|------|
| v0.25.0 | 2026-08-18 | Android / iOS 预编译支持（技术要点已落 build.zig 注释） |
| v0.24.0 | 2026-08-12 | lwIP / libmdbx / lmdbx-zig / cpu_model submodule 迁移 |
| v0.23.0 | 2026-08-09 | 项目初始化（4 submodule + libyaml/yaml_c） |

## 当前基线 — BoringSSL 汇编加速已闭环（zigbox #120-#122，未发 tag）

- 全线汇编（build.zig 注释：setup_wrappers zig-asm :71-76、ASM 参数 :118-124/:149-152、
  findNasm :411-413）：非 Windows → `CMAKE_ASM_COMPILER=zig-asm` 编 .S（3 平台 44 文件 0 失败）；
  Windows x86/x86_64 → NASM 交叉汇编（有 → ASM，无 → 降级 NO_ASM + 告警）；两分支显式
  `-DOPENSSL_NO_ASM=OFF` 防增量 CMakeCache 残留（#122 实测 315 单元无 ASM_NASM 行）。
- aarch64-macos 产物验证：aesv8/ghash-neon/bn-armv8 全进 fipsmodule；协议级收益（CPU 满载）
  tuic +13.1% / trojan +10.3% / anytls +6.8% / hy2 +6.0% / vless-reality +5.5%，vless -0.8% 噪声内，
  全 PASS 无回归（报表 zigbox `pref-2026-08-30-boringssl-asm.md`）。
- Windows x86_64-windows-gnu 已重编（315 单元含全部 -win.asm，nm 88 个 ASM 符号）；数值收益待 windowsvm bench。
- Zig 0.16 经验（unmanaged ArrayList / b.fmt 非 printf）→ zig-codegen.md。
