#!/bin/sh
set -eu

# SingulariX entrypoint: delegate to the maintained core script.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CORE_SCRIPT="$SCRIPT_DIR/platforms/container/nodejs/start.sh"

if [ ! -f "$CORE_SCRIPT" ]; then
  echo "错误: 未找到核心脚本: $CORE_SCRIPT" >&2
  echo "请确认仓库结构完整，或直接运行 platforms/container/nodejs/start.sh" >&2
  exit 1
fi

chmod +x "$CORE_SCRIPT" 2>/dev/null || true
exec sh "$CORE_SCRIPT" "$@"
