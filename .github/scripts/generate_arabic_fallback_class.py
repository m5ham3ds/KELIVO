#!/usr/bin/env python3
"""Build the checked-in Arabic fallback class from the English and Arabic ARB files.

Flutter's own `flutter gen-l10n` remains authoritative in CI. This generator
keeps the checked-in Arabic class usable in environments where Flutter SDK is
not available. It supports ICU plural expressions anywhere in a message,
including messages containing more than one plural expression.
"""
from __future__ import annotations
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EN_PATH = ROOT / "lib/l10n/app_en.arb"
AR_PATH = ROOT / "lib/l10n/app_ar.arb"
OUT_PATH = ROOT / "lib/l10n/app_localizations_ar.dart"
PLURAL_START = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*),\s*plural,")


def dart_string(value: str) -> str:
    """Return a Dart double-quoted string with interpolation disabled."""
    encoded = json.dumps(value, ensure_ascii=False)
    return encoded.replace("$", r"\$")


def interpolate(value: str, names: list[str]) -> str:
    """Return a Dart string expression with declared ARB placeholders interpolated."""
    encoded = dart_string(value)
    for name in names:
        encoded = encoded.replace("{" + name + "}", "${" + name + "}")
    return encoded


def placeholder_types(metadata: dict, key: str) -> dict[str, str]:
    raw = metadata.get("@" + key, {}).get("placeholders", {})
    result = {}
    for name, spec in raw.items():
        typ = spec.get("type", "Object") if isinstance(spec, dict) else "Object"
        result[name] = typ if typ in {"int", "num", "double", "String", "Object"} else "Object"
    return result


def matching_brace(value: str, opening: int) -> int:
    """Return the closing brace matching value[opening]."""
    if opening >= len(value) or value[opening] != "{":
        raise ValueError("Expected an opening ICU brace")
    depth = 0
    for index in range(opening, len(value)):
        if value[index] == "{":
            depth += 1
        elif value[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError(f"Unclosed ICU expression: {value[opening:opening + 80]!r}")


def parse_plural(value: str, match: re.Match[str]) -> tuple[str, dict[str, str], int]:
    """Parse a plural expression beginning at match.start()."""
    variable = match.group(1)
    outer_end = matching_brace(value, match.start())
    pos = match.end()
    branches: dict[str, str] = {}
    while pos < outer_end:
        while pos < outer_end and value[pos].isspace():
            pos += 1
        if pos >= outer_end:
            break
        name_match = re.match(r"(=[0-9]+|[A-Za-z]+)\s*\{", value[pos:outer_end])
        if not name_match:
            raise ValueError(f"Invalid ICU plural branch near: {value[pos:pos + 60]!r}")
        branch = name_match.group(1)
        branch_open = pos + name_match.end() - 1
        branch_end = matching_brace(value, branch_open)
        branches[branch] = value[branch_open + 1:branch_end]
        pos = branch_end + 1
    if "other" not in branches:
        raise ValueError("ICU plural is missing its required 'other' branch")
    return variable, branches, outer_end + 1



def collect_placeholders(value: str) -> list[str]:
    """Collect message variables without confusing ICU branch text with variables."""
    found: list[str] = []

    def add(name: str) -> None:
        if name not in found:
            found.append(name)

    def visit(fragment: str) -> None:
        cursor = 0
        while True:
            match = PLURAL_START.search(fragment, cursor)
            if match is None:
                plain = fragment[cursor:]
                for item in re.findall(r"\{([A-Za-z_][A-Za-z0-9_]*)\}", plain):
                    add(item)
                break
            plain = fragment[cursor:match.start()]
            for item in re.findall(r"\{([A-Za-z_][A-Za-z0-9_]*)\}", plain):
                add(item)
            variable, branches, next_cursor = parse_plural(fragment, match)
            add(variable)
            for branch_body in branches.values():
                visit(branch_body)
            cursor = next_cursor

    visit(value)
    return found

def compile_plural(
    variable: str,
    branches: dict[str, str],
    names: list[str],
    types: dict[str, str],
) -> str:
    """Compile one ICU plural expression into a Dart expression."""
    variable_type = types.get(variable, "int")
    if variable not in names:
        raise ValueError(f"ICU plural variable {variable!r} is missing from ARB placeholder metadata")

    category_parts = []
    exact_parts = []
    for branch, body in branches.items():
        expression = compile_template(body, names, types)
        if branch.startswith("="):
            exact_parts.append((int(branch[1:]), expression))
        else:
            category_parts.append(f"{branch}: {expression}")

    intl_call = (
        f"intl.Intl.pluralLogic({variable}, locale: localeName, "
        + ", ".join(category_parts)
        + ")"
    )
    # Exact ICU selectors take precedence over locale-specific CLDR categories.
    result = intl_call
    for exact_value, expression in reversed(sorted(exact_parts)):
        result = f"({variable} == {exact_value} ? {expression} : {result})"
    return result


def compile_template(value: str, names: list[str], types: dict[str, str]) -> str:
    """Compile normal placeholders and any number of ICU plural expressions."""
    parts: list[str] = []
    cursor = 0
    while True:
        match = PLURAL_START.search(value, cursor)
        if match is None:
            tail = value[cursor:]
            if tail:
                parts.append(interpolate(tail, names))
            break
        prefix = value[cursor:match.start()]
        if prefix:
            parts.append(interpolate(prefix, names))
        variable, branches, next_cursor = parse_plural(value, match)
        parts.append(compile_plural(variable, branches, names, types))
        cursor = next_cursor
    if not parts:
        return dart_string("")
    return " + ".join(parts)


def main() -> None:
    en = json.loads(EN_PATH.read_text(encoding="utf-8"))
    ar = json.loads(AR_PATH.read_text(encoding="utf-8"))
    messages = [(key, value) for key, value in ar.items()
                if not key.startswith("@") and value != en.get(key)]
    chunks = [
        "// Arabic localization overrides. Unreviewed messages inherit the English fallback.",
        "// Flutter gen-l10n regenerates the authoritative classes during CI/build.",
        "import 'package:intl/intl.dart' as intl;",
        "import 'app_localizations_en.dart';",
        "",
        "// ignore_for_file: type=lint",
        "",
        "class AppLocalizationsAr extends AppLocalizationsEn {",
        "  AppLocalizationsAr([String locale = 'ar']) : super(locale);",
        "",
    ]
    for key, value in messages:
        if not isinstance(value, str):
            raise TypeError(f"Arabic message {key} is not a string")
        types = placeholder_types(ar, key)
        inferred_names = collect_placeholders(value)
        if not types:
            # Flutter gen-l10n sorts inferred placeholders alphabetically when
            # the ARB entry has no explicit @placeholders metadata.
            names = sorted(inferred_names)
        else:
            names = list(types)
            for name in inferred_names:
                if name not in names:
                    names.append(name)
                    types.setdefault(name, "Object")
        expression = compile_template(value, names, types)
        has_plural = PLURAL_START.search(value) is not None
        if not names and not has_plural:
            chunks.extend([
                "  @override",
                f"  String get {key} => {expression};",
                "",
            ])
        else:
            signature = ", ".join(
                f"{types.get(name, 'Object')} {name}" for name in names
            )
            chunks.extend([
                "  @override",
                f"  String {key}({signature}) => {expression};",
                "",
            ])
    chunks.append("}")
    OUT_PATH.write_text("\n".join(chunks) + "\n", encoding="utf-8")
    print(f"Generated {len(messages)} Arabic overrides in {OUT_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
