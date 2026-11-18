#!/usr/bin/env python3
"""Validate Arabic ARB key and placeholder parity against the English template."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EN = ROOT / "lib/l10n/app_en.arb"
AR = ROOT / "lib/l10n/app_ar.arb"
STATUS = ROOT / "lib/l10n/app_ar_status.json"


def messages(data: dict) -> dict[str, str]:
    return {key: value for key, value in data.items() if not key.startswith("@")}


def matching_brace(value: str, opening: int) -> int:
    depth = 0
    for index in range(opening, len(value)):
        if value[index] == "{":
            depth += 1
        elif value[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError(f"Unclosed ICU expression: {value[opening:opening + 80]!r}")


def placeholders(value: str) -> set[str]:
    """Collect real placeholders, excluding ICU branch labels and their text."""
    plural_start = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*),\s*plural,")
    found: set[str] = set()

    def visit(fragment: str) -> None:
        cursor = 0
        while True:
            match = plural_start.search(fragment, cursor)
            if match is None:
                found.update(re.findall(r"\{([A-Za-z_][A-Za-z0-9_]*)\}", fragment[cursor:]))
                return
            found.update(re.findall(r"\{([A-Za-z_][A-Za-z0-9_]*)\}", fragment[cursor:match.start()]))
            outer_end = matching_brace(fragment, match.start())
            pos = match.end()
            while pos < outer_end:
                while pos < outer_end and fragment[pos].isspace():
                    pos += 1
                branch = re.match(r"(=[0-9]+|[A-Za-z]+)\s*\{", fragment[pos:outer_end])
                if not branch:
                    raise ValueError(f"Invalid ICU plural branch near: {fragment[pos:pos + 60]!r}")
                branch_open = pos + branch.end() - 1
                branch_end = matching_brace(fragment, branch_open)
                visit(fragment[branch_open + 1:branch_end])
                pos = branch_end + 1
            found.add(match.group(1))
            cursor = outer_end + 1

    visit(value)
    return found


def main() -> int:
    en_data = json.loads(EN.read_text(encoding="utf-8"))
    ar_data = json.loads(AR.read_text(encoding="utf-8"))
    en_messages = messages(en_data)
    ar_messages = messages(ar_data)

    missing = sorted(set(en_messages) - set(ar_messages))
    extra = sorted(set(ar_messages) - set(en_messages))
    if missing or extra:
        print(f"ARB key parity failed: {len(missing)} missing, {len(extra)} extra.", file=sys.stderr)
        for key in missing[:30]:
            print(f"  missing: {key}", file=sys.stderr)
        for key in extra[:30]:
            print(f"  extra: {key}", file=sys.stderr)
        return 1

    mismatches = []
    for key, source in en_messages.items():
        target = ar_messages[key]
        if not isinstance(source, str) or not isinstance(target, str):
            mismatches.append((key, "message is not a string"))
            continue
        source_meta = en_data.get("@" + key, {})
        target_meta = ar_data.get("@" + key, {})
        source_declared = set(source_meta.get("placeholders", {}))
        target_declared = set(target_meta.get("placeholders", {}))
        if source_declared != target_declared:
            mismatches.append((key, "placeholder metadata differs"))
            continue
        if placeholders(source) != placeholders(target):
            mismatches.append((key, "placeholder set differs"))
        elif source_declared - placeholders(source) or target_declared - placeholders(target):
            mismatches.append((key, "declared placeholder is missing from a message"))

    if mismatches:
        print(f"ARB placeholder validation failed for {len(mismatches)} messages.", file=sys.stderr)
        for key, reason in mismatches[:40]:
            print(f"  {key}: {reason}", file=sys.stderr)
        return 1

    translated = sum(1 for key, value in ar_messages.items() if value != en_messages[key])
    coverage = (translated / max(1, len(en_messages))) * 100
    status = {
        "locale": "ar",
        "messageCount": len(en_messages),
        "translatedCount": translated,
        "fallbackEnglishCount": len(en_messages) - translated,
        "translationCoveragePercent": round(coverage, 2),
        "note": "Untranslated values intentionally retain the English template until reviewed Arabic translations are completed.",
    }
    STATUS.write_text(json.dumps(status, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "Arabic ARB parity passed: "
        f"{len(en_messages)} messages, {translated} Arabic translations "
        f"({coverage:.2f}% reviewed coverage), {len(en_messages) - translated} English fallbacks."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
