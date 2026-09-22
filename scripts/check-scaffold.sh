#!/usr/bin/env bash
# 本地快速检查：脚手架文件是否齐全、示例 JSON 是否可解析。不读取真实密钥。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

need=(
  README.md
  .gitignore
  .env.example
  config/mcp.example.json
  docs/permissions.md
  docs/polling.md
  skills/feishu-send/SKILL.md
  skills/feishu-poll-reply/SKILL.md
  routines/feishu-poll-reply.md
  state/watermarks.example.json
)

echo "== 文件存在性 =="
missing=0
for f in "${need[@]}"; do
  if [[ -f "$f" ]]; then
    echo "  OK  $f"
  else
    echo "  MISSING  $f"
    missing=1
  fi
done

echo "== JSON 解析 =="
node -e '
const fs = require("fs");
for (const p of ["config/mcp.example.json", "state/watermarks.example.json"]) {
  JSON.parse(fs.readFileSync(p, "utf8"));
  console.log("  OK  " + p);
}
const mcp = JSON.parse(fs.readFileSync("config/mcp.example.json", "utf8"));
const args = mcp.mcpServers?.["lark-mcp"]?.args || [];
const toolsIdx = args.indexOf("-t");
const tools = toolsIdx >= 0 ? String(args[toolsIdx + 1]).split(",") : [];
const required = ["im.v1.message.create", "im.v1.message.list", "im.v1.chat.list"];
for (const t of required) {
  if (!tools.includes(t)) {
    console.error("  FAIL  mcp tools missing: " + t);
    process.exit(1);
  }
}
const langIdx = args.indexOf("-l");
if (langIdx < 0 || args[langIdx + 1] !== "zh") {
  console.error("  FAIL  expected -l zh");
  process.exit(1);
}
console.log("  OK  lark-mcp tools + language zh");
'

if [[ "$missing" -ne 0 ]]; then
  echo "脚手架不完整" >&2
  exit 1
fi

echo "== 完成：可作为模板使用（请自行配置 APP_ID / APP_SECRET） =="
