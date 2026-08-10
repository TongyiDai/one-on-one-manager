#!/usr/bin/env bash
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
git_ok=0
python_ok=0
lark_ok=0
auth_ok=0

command -v git >/dev/null 2>&1 && git_ok=1
command -v python3 >/dev/null 2>&1 && python_ok=1
command -v lark-cli >/dev/null 2>&1 && lark_ok=1

if [ "$lark_ok" = "1" ]; then
  auth_json="$(LARKSUITE_CLI_NO_UPDATE_NOTIFIER=1 LARKSUITE_CLI_NO_SKILLS_NOTIFIER=1 lark-cli auth status --json --verify 2>/dev/null || true)"
  if [ -n "$auth_json" ] && printf '%s' "$auth_json" | python3 -c 'import json,sys; x=json.load(sys.stdin); raise SystemExit(0 if x.get("identity") == "user" and x.get("verified") is True else 1)' 2>/dev/null; then
    auth_ok=1
  fi
fi

if [ "${1:-}" = "--json" ]; then
  ok=0
  [ "$git_ok" = "1" ] && [ "$python_ok" = "1" ] && [ "$lark_ok" = "1" ] && [ "$auth_ok" = "1" ] && ok=1
  next="run python3 scripts/smoke_test.py"
  [ "$auth_ok" = "1" ] || next="authenticate the current user with lark-cli, then rerun"
  printf '{"ok":%s,"skill_root":"%s","required":{"git":%s,"python3":%s,"lark_cli":%s},"auth":{"identity":"%s","verified":%s},"next":"%s"}\n' \
    "$([ "$ok" = "1" ] && echo true || echo false)" "$root" \
    "$([ "$git_ok" = "1" ] && echo true || echo false)" \
    "$([ "$python_ok" = "1" ] && echo true || echo false)" \
    "$([ "$lark_ok" = "1" ] && echo true || echo false)" \
    "$([ "$auth_ok" = "1" ] && echo user || echo unknown)" \
    "$([ "$auth_ok" = "1" ] && echo true || echo false)" "$next"
  exit 0
fi

echo "skill_root=$root"
echo "git=$([ "$git_ok" = "1" ] && echo ready || echo missing)"
echo "python3=$([ "$python_ok" = "1" ] && echo ready || echo missing)"
echo "lark_cli=$([ "$lark_ok" = "1" ] && echo ready || echo missing)"
echo "auth=$([ "$auth_ok" = "1" ] && echo verified_user || echo unavailable)"
