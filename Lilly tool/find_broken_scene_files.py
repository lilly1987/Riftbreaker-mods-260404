from __future__ import annotations

import sys
from pathlib import Path


DEFAULT_ROOT = Path(r"Y:\SteamLibrary\steamapps\common\Riftbreaker 1849580\mods\Lilly Map\biomes\ice\tiles")


def line_col_from_offset(text: str, offset: int) -> tuple[int, int]:
    line = text.count("\n", 0, offset) + 1
    last_newline = text.rfind("\n", 0, offset)
    col = offset + 1 if last_newline == -1 else offset - last_newline
    return line, col


def check_scene_braces(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace").replace("\r\n", "\n")
    stack: list[int] = []
    issues: list[str] = []

    for index, char in enumerate(text):
        if char == "{":
            stack.append(index)
        elif char == "}":
            if not stack:
                line, col = line_col_from_offset(text, index)
                issues.append(f"unpaired closing brace at line {line}, col {col}")
            else:
                stack.pop()

    for offset in stack:
        line, col = line_col_from_offset(text, offset)
        issues.append(f"missing closing brace for opening brace at line {line}, col {col}")

    return issues


def iter_scene_files(root: Path) -> list[Path]:
    if root.is_file():
        return [root]
    return sorted(root.rglob("*.scene"))


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_ROOT
    if not root.exists():
        print(f"Path not found: {root}")
        return 1

    scene_files = iter_scene_files(root)
    if not scene_files:
        print(f"No .scene files found under: {root}")
        return 1

    broken = 0
    for scene_path in scene_files:
        try:
            issues = check_scene_braces(scene_path)
        except OSError as exc:
            print(f"[ERROR] {scene_path}: {exc}")
            broken += 1
            continue

        if issues:
            broken += 1
            print(f"[BROKEN] {scene_path}")
            for issue in issues:
                print(f"  - {issue}")

    checked = len(scene_files)
    print()
    print(f"Checked {checked} .scene file(s).")
    print(f"Found {broken} problematic file(s).")
    return 0 if broken == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
