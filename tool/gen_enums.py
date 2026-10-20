"""Write the app's wire enums from the backend enum value lists.

The backend publishes every enum value set in `contract-audit/enums.json`, which is exported from
`360ghar-backend/docs/openapi.json`. This script writes one Dart file with a `fromJson` that maps a
missing or unknown value to null (and logs the enum type) and a `toJson` with the wire value. There
is no fallback to a real value. A `JsonConverter` per enum lets `json_serializable` models use it.

Run from the app root:

    python3 tool/gen_enums.py
    python3 tool/gen_enums.py --source ../360ghar-backend/docs/openapi.json

It also copies the value lists the app uses to `test/fixtures/api/enums.json`, which the contract
test compares with the generated enums.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
WORKSPACE = APP.parent
DEFAULT_ENUMS = WORKSPACE / "contract-audit" / "enums.json"
DEFAULT_OPENAPI = WORKSPACE / "360ghar-backend" / "docs" / "openapi.json"
OUT_DART = APP / "lib" / "core" / "data" / "models" / "wire_enums.dart"
OUT_FIXTURE = APP / "test" / "fixtures" / "api" / "enums.json"

# (key in enums.json, Dart name, {wire value: Dart member name} for members that keep an older name)
# A key is `EnumName` for a component enum or `Schema.field` for an inline enum.
WIRE_ENUMS: list[tuple[str, str, dict[str, str]]] = [
    ("PropertyType", "PropertyType", {}),
    ("PropertyPurpose", "PropertyPurpose", {}),
    ("PropertyStatus", "PropertyStatus", {}),
    ("FurnishingLevel", "FurnishingLevel", {}),
    ("KitchenType", "KitchenType", {}),
    ("VentilationType", "VentilationType", {}),
    ("ListingGenderPreference", "ListingGenderPreference", {}),
    ("ListingSharingType", "ListingSharingType", {}),
    ("ImageCategory", "ImageCategory", {}),
    # The UI calls a requested visit "scheduled" and a suggested time "rescheduled".
    (
        "VisitStatus",
        "VisitStatus",
        {"requested": "scheduled", "reschedule_suggested": "rescheduled"},
    ),
    ("VisitContext", "VisitContext", {}),
    ("BugType", "BugType", {}),
    ("BugSeverity", "BugSeverity", {}),
    ("BugStatus", "BugStatus", {}),
    ("AppKey", "AppKey", {}),
    ("AuthMethod", "AuthMethod", {}),
    ("DevicePlatform", "DevicePlatform", {}),
    ("AgentType", "AgentType", {}),
    ("ExperienceLevel", "ExperienceLevel", {}),
    ("UserRole", "UserRole", {}),
    ("SortBy", "SortBy", {}),
    ("PageFormat", "PageFormat", {}),
    ("ErrorData.code", "AssistantErrorCode", {}),
    ("PrivacySettings.profile_visibility", "ProfileVisibility", {}),
    ("IdentifierStatusResponse.channel", "IdentifierChannel", {}),
    ("IdentifierStatusResponse.next_step", "IdentifierNextStep", {}),
]

RESERVED = {
    "abstract", "as", "assert", "async", "await", "break", "case", "catch", "class", "const",
    "continue", "covariant", "default", "deferred", "do", "dynamic", "else", "enum", "export",
    "extends", "extension", "external", "factory", "false", "final", "finally", "for", "function",
    "get", "hide", "if", "implements", "import", "in", "interface", "is", "late", "library",
    "mixin", "new", "null", "on", "operator", "part", "required", "rethrow", "return", "set",
    "show", "static", "super", "switch", "sync", "this", "throw", "true", "try", "typedef", "var",
    "void", "while", "with", "yield",
}


def inline_values(node):
    """Enum values on a schema node: direct, an anyOf member, or array items."""
    if not isinstance(node, dict) or "$ref" in node:
        return None
    if "enum" in node:
        return node["enum"]
    for key in ("anyOf", "oneOf", "allOf"):
        for member in node.get(key, []):
            found = inline_values(member)
            if found:
                return found
    if node.get("type") == "array":
        return inline_values(node.get("items"))
    return None


def from_openapi(spec: dict) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    schemas = spec["components"]["schemas"]
    for name, schema in schemas.items():
        if "enum" in schema:
            out[name] = list(dict.fromkeys(schema["enum"]))
        for field, prop in (schema.get("properties") or {}).items():
            values = inline_values(prop)
            if values:
                out[f"{name}.{field}"] = list(dict.fromkeys(values))
    return out


def load_values(source: Path) -> dict[str, list[str]]:
    data = json.loads(source.read_text())
    return from_openapi(data) if "paths" in data else data


def member_name(wire: str, renames: dict[str, str]) -> str:
    if wire in renames:
        return renames[wire]
    parts = [p for p in re.split(r"[^0-9A-Za-z]+", wire) if p]
    name = parts[0].lower() + "".join(p[:1].upper() + p[1:].lower() for p in parts[1:])
    if not name or name[0].isdigit() or name in RESERVED:
        name = f"v{name[:1].upper()}{name[1:]}" if name else "empty"
    return name


def render(values: dict[str, list[str]]) -> str:
    lines = [
        "// GENERATED BY tool/gen_enums.py from contract-audit/enums.json. DO NOT MODIFY BY HAND.",
        "//",
        "// Each enum reads a missing or unknown wire value as null and logs the enum type. It never",
        "// falls back to a real member. `toJson` returns the wire value.",
        "",
        "import 'package:ghar360/core/utils/debug_logger.dart';",
        "import 'package:json_annotation/json_annotation.dart';",
        "",
        "/// An enum with a backend wire value.",
        "abstract interface class WireEnum {",
        "  String get wire;",
        "}",
        "",
        "T? _decode<T extends WireEnum>(List<T> members, Object? value, Type type) {",
        "  if (value == null) return null;",
        "  for (final member in members) {",
        "    if (member.wire == value) return member;",
        "  }",
        "  DebugLogger.warning('Unknown wire value read as null', type);",
        "  return null;",
        "}",
        "",
    ]
    for key, dart, renames in WIRE_ENUMS:
        wires = values[key]
        members = [(member_name(w, renames), w) for w in wires]
        lines.append(f"/// Wire values of `{key}`.")
        lines.append(f"enum {dart} implements WireEnum {{")
        for index, (name, wire) in enumerate(members):
            end = ";" if index == len(members) - 1 else ","
            lines.append(f"  {name}('{wire}'){end}")
        lines += [
            "",
            f"  const {dart}(this.wire);",
            "",
            "  @override",
            "  final String wire;",
            "",
            "  /// Null for a missing or unknown value.",
            f"  static {dart}? fromJson(Object? value) => _decode(values, value, {dart});",
            "",
            "  String toJson() => wire;",
            "}",
            "",
            f"class {dart}Converter implements JsonConverter<{dart}?, Object?> {{",
            f"  const {dart}Converter();",
            "",
            "  @override",
            f"  {dart}? fromJson(Object? json) => {dart}.fromJson(json);",
            "",
            "  @override",
            f"  Object? toJson({dart}? object) => object?.wire;",
            "}",
            "",
        ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_ENUMS if DEFAULT_ENUMS.exists() else DEFAULT_OPENAPI,
        help="enums.json, or an OpenAPI document",
    )
    args = parser.parse_args()
    values = load_values(args.source)
    missing = [key for key, _, _ in WIRE_ENUMS if key not in values]
    if missing:
        print(f"missing in {args.source}: {', '.join(missing)}", file=sys.stderr)
        return 1
    for key, _, renames in WIRE_ENUMS:
        stale = set(renames) - set(values[key])
        if stale:
            print(f"rename for a value that is not in {key}: {sorted(stale)}", file=sys.stderr)
            return 1
    OUT_DART.write_text(render(values))
    OUT_FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    used = {dart: values[key] for key, dart, _ in WIRE_ENUMS}
    OUT_FIXTURE.write_text(json.dumps(used, indent=2, sort_keys=True) + "\n")
    subprocess.run(["dart", "format", str(OUT_DART)], check=False, cwd=APP)
    print(f"wrote {OUT_DART.relative_to(APP)} and {OUT_FIXTURE.relative_to(APP)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
