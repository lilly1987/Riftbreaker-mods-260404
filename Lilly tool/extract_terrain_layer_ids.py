from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path


RECORD_PREFIX = bytes.fromhex("01 B9 14 06")
RECORD_SUFFIX = bytes.fromhex("00 04 47 6F")


class ExtractError(Exception):
    pass


def parse_args(argv: list[str]) -> tuple[list[str], Path | None]:
    terrain_files: list[str] = []
    config_path: Path | None = None
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--update-config":
            if index + 1 < len(argv) and not argv[index + 1].startswith("--"):
                config_path = Path(argv[index + 1]).resolve()
                index += 2
            else:
                config_path = Path(__file__).resolve().parent / "apply_terrain_config.yml"
                index += 1
            continue
        terrain_files.append(arg)
        index += 1
    return terrain_files, config_path


def find_layer_ids(data: bytes) -> list[tuple[int, bytes]]:
    results: list[tuple[int, bytes]] = []
    cursor = 0
    while True:
        index = data.find(RECORD_PREFIX, cursor)
        if index == -1:
            break
        id_start = index + len(RECORD_PREFIX)
        layer_id = data[id_start:id_start + 5]
        suffix_start = id_start + 5
        if len(layer_id) == 5 and data[suffix_start:suffix_start + len(RECORD_SUFFIX)] == RECORD_SUFFIX:
            results.append((id_start, layer_id))
        cursor = index + 1
    return results


def format_hex(value: bytes) -> str:
    return value.hex(" ").upper()


def collect_layer_ids(path: Path) -> tuple[int, int, list[tuple[bytes, int, int]]]:
    if not path.exists():
        raise ExtractError(f"File not found: {path}")
    if path.suffix.lower() != ".terrain":
        raise ExtractError(f"Only .terrain files are supported: {path}")

    data = path.read_bytes()
    records = find_layer_ids(data)
    if not records:
        raise ExtractError(f"No layer ids found in: {path}")

    counts = Counter(layer_id for _, layer_id in records)
    first_offsets: dict[bytes, int] = {}
    for offset, layer_id in records:
        first_offsets.setdefault(layer_id, offset)

    ordered = [
        (layer_id, count, first_offsets[layer_id])
        for layer_id, count in counts.most_common()
    ]
    return len(data), len(records), ordered


def print_analysis(path: Path, size: int, record_count: int, ordered: list[tuple[bytes, int, int]]) -> None:
    print(f"FILE: {path}")
    print(f"SIZE: {size}")
    print(f"LAYER_RECORDS: {record_count}")
    print("IDS:")
    for index, (layer_id, count, first_offset) in enumerate(ordered, start=1):
        print(f"  {index}. id={format_hex(layer_id)} count={count} first_offset=0x{first_offset:08X}")

    print("\nYAML:")
    print("detected_layer_ids:")
    for index, (layer_id, _, _) in enumerate(ordered, start=1):
        print(f"  layer_{index}: {format_hex(layer_id)}")
    print()


def update_config(config_path: Path, ordered: list[tuple[bytes, int, int]]) -> None:
    if not config_path.exists():
        raise ExtractError(f"Config file not found: {config_path}")

    lines = config_path.read_text(encoding="utf-8").replace("\r\n", "\n").splitlines()
    start = None
    end = None

    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "detected_layer_ids:":
            start = index
            continue
        if start is not None and index > start:
            if line and not line.startswith((" ", "\t")):
                end = index
                break

    new_section = ["detected_layer_ids:"]
    for index, (layer_id, _, _) in enumerate(ordered, start=1):
        new_section.append(f"  layer_{index}: {format_hex(layer_id)}")

    if start is None:
        if lines and lines[-1] != "":
            lines.append("")
        lines.extend(new_section)
    else:
        if end is None:
            end = len(lines)
        lines = lines[:start] + new_section + lines[end:]

    config_path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    terrain_args, config_path = parse_args(sys.argv[1:])
    if not terrain_args:
        print("Usage: extract_terrain_layer_ids.py <terrain file> [more terrain files...] [--update-config [path]]")
        return 1

    analyses: list[tuple[Path, int, int, list[tuple[bytes, int, int]]]] = []
    for raw_path in terrain_args:
        try:
            path = Path(raw_path).resolve()
            size, record_count, ordered = collect_layer_ids(path)
            analyses.append((path, size, record_count, ordered))
            print_analysis(path, size, record_count, ordered)
        except ExtractError as exc:
            print(f"Error: {exc}")
            return 1

    if config_path is not None:
        try:
            update_config(config_path, analyses[-1][3])
            print(f"Updated config: {config_path}")
        except ExtractError as exc:
            print(f"Error: {exc}")
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
