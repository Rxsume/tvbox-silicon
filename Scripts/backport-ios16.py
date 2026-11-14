#!/usr/bin/env python3
"""
Backport Yingxia (tvbox-silicon) from iOS 17 (@Observable / Observation) to iOS 16
(ObservableObject / Combine).

The Observation framework and the @Observable macro require iOS 17. On iOS 16 the
app would fail to launch, so every @Observable class must become an ObservableObject
with @Published storage properties. This script does the mechanical part of that
migration and reports exactly what it changed.

Usage:
    python3 Scripts/backport-ios16.py --check      # dry run, print a diff plan
    python3 Scripts/backport-ios16.py --apply      # write the changes
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_DIRS = [ROOT / "Sources", ROOT / "App"]

# @MainActor @Observable [public|private] final class Name[: Inheritance] {
CLASS_RE = re.compile(
    r"^(?P<indent>[ \t]*)(?P<ma>@MainActor[ \t]+)?@Observable[ \t]+"
    r"(?P<access>public[ \t]+|private[ \t]+|internal[ \t]+)?final[ \t]+class[ \t]+"
    r"(?P<name>\w+)(?P<inherit>:[^\n{]*)?[ \t]*\{?[ \t]*$"
)

# @ObservationIgnored prefix (attribute that suppresses observation)
IGNORED_RE = re.compile(r"^([ \t]*)@ObservationIgnored[ \t]+(.*)$")

# A `var` member declaration (handled only at depth 1 of a migrated class).
VAR_RE = re.compile(
    r"^(?P<indent>[ \t]*)(?P<mod>(?:public[ \t]+|internal[ \t]+|"
    r"private\(set\)[ \t]+|fileprivate\(set\)[ \t]+|internal\(set\)[ \t]+)*)"
    r"var[ \t]+(?P<name>\w+)(?P<rest>.*)$"
)

# Class declaration line AFTER the transform step (name used to locate the body).
CLS_RE = re.compile(
    r"^(?:@MainActor[ \t]+)?(?:public[ \t]+|private[ \t]+|internal[ \t]+)?"
    r"final[ \t]+class[ \t]+(\w+)"
)


def _is_computed(rest: str) -> bool:
    """True when the declaration is a computed property (single- or multi-line).

    A stored property either has no `{` in its declaration, or its `{` follows an
    `=` (closure/trailing-closure initializer). A computed property's body `{`
    appears before any `=` (typically there is no `=` at all).
    """
    stripped = rest.strip()
    if stripped.startswith("="):
        return False
    brace = stripped.find("{")
    if brace < 0:
        return False
    eq = stripped.find("=")
    return eq < 0 or eq > brace


def _has_observer(lines: list[str], i: int, lookahead: int = 4) -> bool:
    """Whether a `var x: T {` body is a stored property with didSet/willSet."""
    for k in range(i + 1, min(i + 1 + lookahead, len(lines))):
        if re.search(r"\b(?:didSet|willSet)\b", lines[k]):
            return True
    return False


def _skip_var(line: str, mod: str) -> bool:
    """Only type-level and non-observable members are skipped here.

    `private var` never reaches VAR_RE (its modifier isn't in the regex), so
    plain `public`/`internal` members must be published; views read them.
    """
    s = line.strip()
    return bool(re.match(r"^(static|class|lazy|weak|unowned)\b", s))


def transform(text: str, path: Path) -> tuple[str, list[str], set[str]]:
    lines = text.splitlines()
    out: list[str] = []
    report: list[str] = []
    ignored: set[str] = set()
    for raw in lines:
        stripped = raw.strip()
        if stripped == "import Observation":
            out.append(raw.replace("Observation", "Combine"))
            report.append("  import Observation -> import Combine")
            continue
        m = IGNORED_RE.match(raw)
        if m:
            new_line = f"{m.group(1)}{m.group(2)}"
            out.append(new_line)
            ignored.add(new_line.strip())
            report.append(f"  @ObservationIgnored removed: {m.group(2).strip()[:50]}")
            continue
        m = CLASS_RE.match(raw)
        if m:
            indent = m.group("indent")
            ma = "@MainActor " if m.group("ma") else ""
            access = m.group("access") or ""
            name = m.group("name")
            inherit = (m.group("inherit") or "").strip()
            new_inherit = f"{inherit}, ObservableObject" if inherit else ": ObservableObject"
            out.append(f"{indent}{ma}{access}final class {name}{new_inherit} {{")
            report.append(f"  class {name}: @Observable -> ObservableObject")
            continue
        out.append(raw)
    return "\n".join(out), report, ignored


def add_published(text: str, observable_names: set[str], ignored: set[str]) -> tuple[str, list[str]]:
    lines = text.splitlines()
    out: list[str] = []
    report: list[str] = []
    i, n = 0, len(lines)

    while i < n:
        m = CLS_RE.match(lines[i])
        if m and m.group(1) in observable_names:
            out.append(lines[i])
            i += 1
            depth = lines[i - 1].count("{") - lines[i - 1].count("}")
            while i < n and depth > 0:
                line = lines[i]
                if depth == 1:
                    handled = False
                    v = VAR_RE.match(line)
                    if v:
                        rest, mod, name = v.group("rest"), v.group("mod"), v.group("name")
                        if line.strip() in ignored:
                            out.append(line)
                        elif _skip_var(line, mod):
                            out.append(line)
                        elif _is_computed(rest) and not _has_observer(lines, i):
                            out.append(line)  # computed property: leave alone
                        else:
                            out.append(f"{v.group('indent')}@Published {mod}var {name}{rest}")
                            report.append(f"  @Published added: {name}")
                        handled = True
                    if not handled:
                        out.append(line)
                else:
                    out.append(line)
                depth += line.count("{") - line.count("}")
                i += 1
            continue
        out.append(lines[i])
        i += 1
    return "\n".join(out), report


def collect_observable_names(text: str) -> set[str]:
    return {m.group("name") for m in (CLASS_RE.match(l) for l in text.splitlines()) if m}


def process(path: Path, apply: bool) -> None:
    text = path.read_text(encoding="utf-8")
    names = collect_observable_names(text)
    if not names:
        return
    new_text, r1, ignored = transform(text, path)
    new_text, r2 = add_published(new_text, names, ignored)
    if new_text == text:
        return
    print(f"\n=== {path.relative_to(ROOT)} ===")
    print(f"  @Observable classes: {', '.join(sorted(names))}")
    for line in r1 + r2:
        print(line)
    if apply:
        path.write_text(new_text, encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="dry run, print the plan")
    ap.add_argument("--apply", action="store_true", help="write changes to disk")
    args = ap.parse_args()
    if not (args.check or args.apply):
        ap.error("pass --check or --apply")
    for d in SWIFT_DIRS:
        for path in sorted(d.rglob("*.swift")):
            process(path, apply=args.apply)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
