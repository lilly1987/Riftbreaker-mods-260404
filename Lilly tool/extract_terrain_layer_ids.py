from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path


STANDARD_PREFIX = bytes.fromhex("D1 B1 0D 01 0C 00 01 B9 14 06")
STANDARD_SUFFIX = bytes.fromhex("00 04 47 6F")
ZERO_TAIL_SUFFIX = bytes.fromhex("04 47 6F")
EMPTY_PREFIX = bytes.fromhex("D1 B1 0D 00 0C 00 04 47 6F")
DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent / "apply_terrain_config.yml"


class ExtractError(Exception):
    pass


def format_hex(value: bytes) -> str:
    return value.hex(" ").upper()


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


def classify_variant(variant: bytes) -> tuple[str, bytes | None]:
    if variant == EMPTY_PREFIX:
        return "empty", None

    layer_id = variant[len(STANDARD_PREFIX):len(STANDARD_PREFIX) + 5]
    if variant.endswith(STANDARD_SUFFIX):
        return "standard", layer_id
    if variant.endswith(ZERO_TAIL_SUFFIX):
        return "zero_tail", layer_id

    return "unknown", None


def find_layer_records(data: bytes) -> list[tuple[int, int, bytes]]:
    records: list[tuple[int, int, bytes]] = []
    cursor = 0
    data_len = len(data)

    while cursor < data_len:
        standard_index = data.find(STANDARD_PREFIX, cursor)
        empty_index = data.find(EMPTY_PREFIX, cursor)
        candidates = [index for index in (standard_index, empty_index) if index != -1]
        if not candidates:
            break

        index = min(candidates)
        variant: bytes | None = None

        if index == empty_index:
            variant = EMPTY_PREFIX
        else:
            id_start = index + len(STANDARD_PREFIX)
            layer_id = data[id_start:id_start + 5]
            suffix_start = id_start + 5
            full_end = suffix_start + len(STANDARD_SUFFIX)
            short_end = suffix_start + len(ZERO_TAIL_SUFFIX)

            if (
                len(layer_id) == 5
                and data[suffix_start:full_end] == STANDARD_SUFFIX
            ):
                variant = data[index:full_end]
            elif (
                len(layer_id) == 5
                and layer_id[-1] == 0
                and data[suffix_start:short_end] == ZERO_TAIL_SUFFIX
            ):
                variant = data[index:short_end]

        if variant is not None:
            records.append((index, index + len(variant), variant))
            cursor = index + len(variant)
        else:
            cursor = index + 1

    return records


def build_variant_labels(variants: list[bytes]) -> dict[bytes, str]:
    counts = Counter(variants)
    labels: dict[bytes, str] = {}
    standard_index = 1
    zero_tail_index = 1

    for variant, _ in counts.most_common():
        kind, _ = classify_variant(variant)
        if kind == "empty":
            labels[variant] = "empty"
        elif kind == "standard":
            labels[variant] = f"layer_{standard_index}"
            standard_index += 1
        elif kind == "zero_tail":
            labels[variant] = f"zero_tail_layer_{zero_tail_index}"
            zero_tail_index += 1
        else:
            labels[variant] = f"variant_{len(labels) + 1}"

    return labels


def collect_layer_ids(path: Path) -> tuple[int, int, list[tuple[str, bytes, int, int]]]:
    if not path.exists():
        raise ExtractError(f"File not found: {path}")
    if path.suffix.lower() != ".terrain":
        raise ExtractError(f"Only .terrain files are supported: {path}")

    data = path.read_bytes()
    records = find_layer_records(data)
    if not records:
        raise ExtractError(f"No layer ids found in: {path}")

    variants = [variant for _, _, variant in records]
    counts = Counter(variants)
    first_offsets: dict[bytes, int] = {}
    for offset, _, variant in records:
        first_offsets.setdefault(variant, offset)

    labels = build_variant_labels(list(counts.keys()))
    ordered = [
        (labels[variant], variant, count, first_offsets[variant])
        for variant, count in counts.most_common()
    ]
    return len(data), len(records), ordered


def print_analysis(path: Path, size: int, record_count: int, ordered: list[tuple[str, bytes, int, int]]) -> None:
    print(f"FILE: {path}")
    print(f"SIZE: {size}")
    print(f"LAYER_RECORDS: {record_count}")
    print("IDS:")
    for label, variant, count, first_offset in ordered:
        kind, layer_id = classify_variant(variant)
        if kind == "empty":
            detail = "empty-layer representation"
        elif layer_id is not None:
            detail = f"{kind} {format_hex(layer_id)}"
        else:
            detail = format_hex(variant)
        print(f"  {label} = {detail} count={count} first_offset=0x{first_offset:08X}")

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


def update_config(config_path: Path, ordered: list[tuple[str, bytes, int, int]]) -> None:
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
    for label, variant, _, _ in ordered:
        kind, layer_id = classify_variant(variant)
        if kind == "empty":
            layer_lines.append(f"  {label}: 00 00 00 00 00")
        elif layer_id is not None:
            layer_lines.append(f"  {label}: {format_hex(layer_id)}")

    blocks = ["\n".join(layer_lines)]
    blocks.extend(other_sections)
    config_path.write_text("\n\n".join(blocks).rstrip() + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    terrain_paths, config_path = parse_args(sys.argv[1:])
    if not terrain_paths:
        print("Usage: extract_terrain_layer_ids.py <terrain file> [more terrain files...] [--update-config [path]]")
        return 1

    last_ordered: list[tuple[str, bytes, int, int]] | None = None

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
