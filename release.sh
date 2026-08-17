#!/usr/bin/env bash
# release.sh — 全平台构建预编译静态库并 commit + push
#
# 用法:
#   ./release.sh [选项] [commit 消息]
#
# 选项:
#   --incremental   增量构建（跳过清理 build 目录，默认全量重建）
#   --no-push       只构建 + commit，不 push
#   -h, --help      显示本帮助
#
# 说明:
#   全量重建 aarch64/x86_64 × linux-musl/windows-gnu/macos-none 共 6 个 target，
#   将产物（zig-out/<target>/lib/*.a 与 include/*.h）加入 git 并 commit，
#   默认 push 到当前分支的 upstream。
#   运行前请先 git submodule update --recursive 更新子模块到目标版本。

set -euo pipefail
cd "$(dirname "$0")"

# ---- 可配置项 ----
TARGETS=(
  aarch64-linux-musl
  x86_64-linux-musl
  aarch64-windows-gnu
  x86_64-windows-gnu
  aarch64-macos-none
  x86_64-macos-none
)
DEFAULT_MSG="build: rebuild prebuilt static libraries"

usage() {
  cat <<'EOF'
用法:
  ./release.sh [选项] [commit 消息]

选项:
  --incremental   增量构建（跳过清理 build 目录，默认全量重建）
  --no-push       只构建 + commit，不 push
  -h, --help      显示本帮助

说明:
  全量重建 aarch64/x86_64 × linux-musl/windows-gnu/macos-none 共 6 个 target，
  产物写入 zig-out/<target>/，加入 git 后 commit，默认 push 到 upstream。
  运行前请先 git submodule update --recursive 更新子模块到目标版本。
EOF
}

# ---- 参数解析 ----
CLEAN=1
PUSH=1
MSG="$DEFAULT_MSG"
for arg in "$@"; do
  case "$arg" in
    --incremental) CLEAN=0 ;;
    --no-push)     PUSH=0 ;;
    -h|--help)     usage; exit 0 ;;
    *)             MSG="$arg" ;;
  esac
done

# ---- 前置检查 ----
for cmd in zig cmake ninja git; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "错误: 未找到 $cmd"; exit 1; }
done
[ -f boringssl/CMakeLists.txt ] || {
  echo "错误: boringssl 子模块未初始化，请先 git submodule update --init --recursive"
  exit 1
}

echo "==> 构建 ${#TARGETS[@]} 个 target：${TARGETS[*]}"
echo "==> 清理旧 build 目录：$([ "$CLEAN" = 1 ] && echo 是 || echo 否)"

# ---- 构建 ----
for t in "${TARGETS[@]}"; do
  echo
  echo "===== 构建 $t ====="
  [ "$CLEAN" = 1 ] && rm -rf "build/$t"
  zig build -Dtarget="$t"
done

# ---- 提交 ----
git add build.zig .gitignore zig-out
if git diff --cached --quiet; then
  echo
  echo "==> 无内容变更（产物与上次相同），跳过 commit/push"
  exit 0
fi

echo
echo "==> 将提交以下变更："
git diff --cached --stat | tail -8
git commit -m "$MSG"

# ---- push ----
if [ "$PUSH" = 1 ]; then
  echo
  echo "==> push 到 upstream"
  git push
fi
