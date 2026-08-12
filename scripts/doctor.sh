#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
git_ok=0
python_ok=0
lark_ok=0
auth_ok=0
auth_identity=unknown
auth_verified=false
next="authenticate the current user with lark-cli, then rerun"

command -v git >/dev/null 2>&1 && git_ok=1
command -v python3 >/dev/null 2>&1 && python_ok=1
command -v lark-cli >/dev/null 2>&1 && lark_ok=1

if [ "$lark_ok" = "1" ]; then
  auth_out="$(LARKSUITE_CLI_NO_UPDATE_NOTIFIER=1 LARKSUITE_CLI_NO_SKILLS_NOTIFIER=1 lark-cli auth status --json --verify 2>&1 || true)"
  if printf '%s' "$auth_out" | python3 -c 'import json,sys; p=json.load(sys.stdin); raise SystemExit(0 if p.get("identity") == "user" and p.get("verified") is True else 1)' 2>/dev/null; then
    auth_ok=1
    auth_identity=user
    auth_verified=true
    next="run python3 scripts/smoke_test.py"
  elif printf '%s' "$auth_out" | grep -Eqi 'unknown command|no such command|unrecognized command'; then
    contact_out="$(LARKSUITE_CLI_NO_UPDATE_NOTIFIER=1 LARKSUITE_CLI_NO_SKILLS_NOTIFIER=1 lark-cli contact +get-user --as user --json 2>/dev/null || true)"
    if printf '%s' "$contact_out" | python3 -c 'import json,sys; p=json.load(sys.stdin); u=(p.get("data") or {}).get("user") or {}; raise SystemExit(0 if p.get("ok") is True and p.get("identity") == "user" and bool(u.get("open_id") or u.get("openId")) else 1)' 2>/dev/null; then
      auth_ok=1
      auth_identity=user
      next="run python3 scripts/smoke_test.py"
    else
      task_out="$(LARKSUITE_CLI_NO_UPDATE_NOTIFIER=1 LARKSUITE_CLI_NO_SKILLS_NOTIFIER=1 lark-cli task +get-my-tasks --as user --json 2>/dev/null || true)"
      if printf '%s' "$task_out" | python3 -c 'import json,sys; p=json.load(sys.stdin); raise SystemExit(0 if p.get("ok") is True and p.get("identity") == "user" else 1)' 2>/dev/null; then
        auth_ok=1
        auth_identity=user_context
        next="run python3 scripts/smoke_test.py; confirm exact target user/tenant before any write"
      fi
    fi
  fi
fi

if [ "${1:-}" = "--json" ]; then
  ok=0
  [ "$git_ok" = "1" ] && [ "$python_ok" = "1" ] && [ "$lark_ok" = "1" ] && [ "$auth_ok" = "1" ] && ok=1
  printf '{"ok":%s,"skill_root":"%s","required":{"git":%s,"python3":%s,"lark_cli":%s},"auth":{"identity":"%s","verified":%s},"next":"%s"}\n' \
    "$([ "$ok" = "1" ] && echo true || echo false)" "$root" \
    "$([ "$git_ok" = "1" ] && echo true || echo false)" \
    "$([ "$python_ok" = "1" ] && echo true || echo false)" \
    "$([ "$lark_ok" = "1" ] && echo true || echo false)" \
    "$auth_identity" \
    "$auth_verified" "$next"
  exit 0
fi

echo "skill_root=$root"
echo "git=$([ "$git_ok" = "1" ] && echo ready || echo missing)"
echo "python3=$([ "$python_ok" = "1" ] && echo ready || echo missing)"
echo "lark_cli=$([ "$lark_ok" = "1" ] && echo ready || echo missing)"
echo "auth=$([ "$auth_ok" = "1" ] && echo "$auth_identity" || echo unavailable)"
