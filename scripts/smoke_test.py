#!/usr/bin/env python3
"""Offline smoke test for the public 1:1 manager Skill."""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def require(path: Path) -> None:
    if not path.exists():
        errors.append(f"missing: {path.relative_to(ROOT)}")


for rel in (
    "SKILL.md",
    "agents/openai.yaml",
    "references/runtime.md",
    "references/feishu-routing.md",
    "references/one-on-one-principles.md",
    "references/output-templates.md",
    "scripts/doctor.sh",
):
    require(ROOT / rel)


skill = (ROOT / "SKILL.md").read_text(encoding="utf-8")
if not skill.startswith("---\n") or "name: one-on-one-manager" not in skill:
    errors.append("SKILL.md frontmatter is incomplete")

metadata = (ROOT / "agents/openai.yaml").read_text(encoding="utf-8")
for key in ("display_name:", "short_description:", "default_prompt:", "allow_implicit_invocation:"):
    if key not in metadata:
        errors.append(f"agents/openai.yaml missing {key}")

readme = (ROOT / "README.md").read_text(encoding="utf-8")
for image in re.findall(r'src="([^"]+\.svg)"', readme):
    require(ROOT / image)

for scene in sorted((ROOT / "assets/boards").glob("*.scene.json")):
    try:
        data = json.loads(scene.read_text(encoding="utf-8"))
        nodes = {node["id"] for node in data["nodes"]}
        assert data["canvas"]["width"] == 1200
        assert data["canvas"]["height"] == 675
        assert data["style"]["accent_color"] == "#2F6BFF"
        assert data["intent"]["focus_node"] in nodes
        for edge in data["edges"]:
            assert edge["from"] in nodes and edge["to"] in nodes
    except Exception as exc:  # noqa: BLE001 - smoke test should report all failures
        errors.append(f"invalid scene {scene.name}: {exc}")

for svg in sorted((ROOT / "assets/boards").glob("*.svg")):
    try:
        ET.parse(svg)
        text = svg.read_text(encoding="utf-8")
        if 'width="1200"' not in text or 'height="675"' not in text:
            errors.append(f"non-1200x675 svg: {svg.name}")
    except Exception as exc:  # noqa: BLE001 - smoke test should report all failures
        errors.append(f"invalid svg {svg.name}: {exc}")

if errors:
    print("SMOKE FAILED")
    print("\n".join(f"- {error}" for error in errors))
    sys.exit(1)

print("SMOKE OK")
print(f"skill_root={ROOT}")
print(f"boards={len(list((ROOT / 'assets/boards').glob('*.svg')))}")
print("live_feishu_access=not_checked")
