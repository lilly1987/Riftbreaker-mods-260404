from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path


RECORD_PREFIX = bytes.fromhex("01 B9 14 06")
RECORD_SUFFIX = bytes.fromhex("00 04 47 6F")
DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent / "apply_terrain_config.yml"


class ExtractError(Exception):
    pass


def parse_args(argv: list[str]) -> tuple[list[Path], Path | None]:
    terrain_paths: list[Path] = []
    config_path: Path | None = None
    index = 0

    while index < len(argv):
        arg = argv[index]
        if arg == "--update-config":
            if index + 1 < len(argv) and not argv[index + 1].startswith("--"):
                config_path = Path(argv[index + 1]).resolve()
                index += 2
            else:
                config_path = DEFAULT_CONFIG_PATH
                index += 1
            continue

        terrain_paths.append(Path(arg).resolve())
        index += 1

    return terrain_paths, config_path


def format_hex(value: bytes) -> str:
    return value.hex(" ").upper()


def parse_hex_id(value: str) -> bytes:
    cleaned = value.replace(" ", "").strip()
    data = bytes.fromhex(cleaned)
    if len(data) != 5:
        raise ExtractError(f"Layer id must be exactly 5 bytes: {value}")
    return data


def find_layer_records(data: bytes) -> list[tuple[int, bytes]]:
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


def collect_layer_ids(path: Path) -> tuple[int, int, list[tuple[bytes, int, int]]]:
    if not path.exists():
        raise ExtractError(f"File not found: {path}")
    if path.suffix.lower() != ".terrain":
        raise ExtractError(f"Only .terrain files are supported: {path}")

    data = path.read_bytes()
    records = find_layer_records(data)
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
        print(f"  {index}. layer_{index} = {format_hex(layer_id)} count={count} first_offset=0x{first_offset:08X}")

    print()


def parse_simple_yaml_sections(text: str) -> list[tuple[str, list[str]]]:
    sections: list[tuple[str, list[str]]] = []
    current_name: str | None = None
    current_lines: list[str] = []

    for raw_line in text.replace("\r\n", "\n").splitlines():
        stripped = raw_line.strip()
        indent = len(raw_line) - len(raw_line.lstrip(" "))

        if stripped and indent == 0 and stripped.endswith(":"):
            if current_name is not None:
                sections.append((current_name, current_lines))
            current_name = stripped[:-1]
            current_lines = []
        elif current_name is not None:
            current_lines.append(raw_line)

    if current_name is not None:
        sections.append((current_name, current_lines))

    return sections


def update_config(config_path: Path, ordered: list[tuple[bytes, int, int]]) -> None:
    existing_text = ""
    if config_path.exists():
        existing_text = config_path.read_text(encoding="utf-8").replace("\r\n", "\n")

    sections = parse_simple_yaml_sections(existing_text)
    other_sections: list[str] = []
    for name, lines in sections:
        if name == "layer_ids":
            continue

        block_lines = [f"{name}:"]
        block_lines.extend(lines)
        while block_lines and block_lines[-1] == "":
            block_lines.pop()
        other_sections.append("\n".join(block_lines))

    layer_lines = ["layer_ids:"]
    for index, (layer_id, _, _) in enumerate(ordered, start=1):
        layer_lines.append(f"  layer_{index}: {format_hex(layer_id)}")

    blocks = ["\n".join(layer_lines)]
    blocks.extend(other_sections)
    config_path.write_text("\n\n".join(blocks).rstrip() + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    terrain_paths, config_path = parse_args(sys.argv[1:])
    if not terrain_paths:
        print("Usage: extract_terrain_layer_ids.py <terrain file> [more terrain files...] [--update-config [path]]")
        return 1

    last_ordered: list[tuple[bytes, int, int]] | None = None

    for path in terrain_paths:
        try:
            size, record_count, ordered = collect_layer_ids(path)
        except ExtractError as exc:
            print(f"Error: {exc}")
            return 1

        print_analysis(path, size, record_count, ordered)
        last_ordered = ordered

    if config_path is not None and last_ordered is not None:
        update_config(config_path, last_ordered)
        print(f"Updated config: {config_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
