from __future__ import annotations

import random
import sys
from collections import Counter
from pathlib import Path


STANDARD_PREFIX = bytes.fromhex("D1 B1 0D 01 0C 00 01 B9 14 06")
STANDARD_SUFFIX = bytes.fromhex("00 04 47 6F")
ZERO_TAIL_SUFFIX = bytes.fromhex("04 47 6F")
EMPTY_PREFIX = bytes.fromhex("D1 B1 0D 00 0C 00 04 47 6F")


class TerrainConfigError(Exception):
    pass


def format_hex(value: bytes) -> str:
    return value.hex(" ").upper()


def build_backup_path(terrain_path: Path) -> Path:
    backup_path = terrain_path.with_suffix(terrain_path.suffix + ".bak")
    if not backup_path.exists():
        return backup_path

    index = 1
    while True:
        candidate = terrain_path.with_suffix(terrain_path.suffix + f".bak{index}")
        if not candidate.exists():
            return candidate
        index += 1


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
        kind, layer_id = classify_variant(variant)
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


def apply_random_layers(data: bytes) -> tuple[bytes, dict[str, int], dict[str, int], int, list[str]]:
    records = find_layer_records(data)
    if not records:
        raise TerrainConfigError("No compatible layer records were found in the terrain file.")

    variants = [variant for _, _, variant in records]
    unique_variants = []
    seen: set[bytes] = set()
    for variant in variants:
        if variant not in seen:
            unique_variants.append(variant)
            seen.add(variant)

    labels = build_variant_labels(unique_variants)
    before_counts = {label: 0 for label in labels.values()}
    after_counts = {label: 0 for label in labels.values()}
    rng = random.Random()
    changed = 0
    notes: list[str] = []

    if len(unique_variants) == 1:
        notes.append("Only one layer representation was found, so nothing can be mixed.")

    parts: list[bytes] = []
    cursor = 0

    for start, end, variant in records:
        parts.append(data[cursor:start])

        before_counts[labels[variant]] += 1
        new_variant = rng.choice(unique_variants)
        parts.append(new_variant)

        if new_variant != variant:
            changed += 1

        after_counts[labels[new_variant]] += 1
        cursor = end

    parts.append(data[cursor:])
    output = b"".join(parts)

    notes.append(f"Mixed {len(unique_variants)} layer representations.")
    for variant in unique_variants:
        kind, layer_id = classify_variant(variant)
        label = labels[variant]
        if kind == "empty":
            notes.append(f"{label}: empty-layer representation")
        elif layer_id is not None:
            notes.append(f"{label}: {kind} {format_hex(layer_id)}")

    return output, before_counts, after_counts, changed, notes


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: terrain_apply_config.py <terrain file>")
        return 1

    terrain_path = Path(sys.argv[1]).resolve()
    if not terrain_path.exists():
        print(f"File not found: {terrain_path}")
        return 1
    if terrain_path.suffix.lower() != ".terrain":
        print(f"Only .terrain files are supported: {terrain_path}")
        return 1

    try:
        original = terrain_path.read_bytes()
        updated, before_counts, after_counts, changed, notes = apply_random_layers(original)
        if changed == 0:
            print(f"No matching layer ids were changed in: {terrain_path}")
            for note in notes:
                print(f"Note: {note}")
            return 0
        backup_path = build_backup_path(terrain_path)
        backup_path.write_bytes(original)
        terrain_path.write_bytes(updated)
    except TerrainConfigError as exc:
        print(f"Error: {exc}")
        return 1

    print(f"Updated: {terrain_path}")
    print(f"Backup: {backup_path}")
    print(f"Changed records: {changed}")
    print("Before:")
    for name, count in before_counts.items():
        print(f"  {name}: {count}")
    print("After:")
    for name, count in after_counts.items():
        print(f"  {name}: {count}")
    for note in notes:
        print(f"Note: {note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
