from __future__ import annotations

import random
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = ROOT_DIR / "apply_terrain_config.yml"
RECORD_PREFIX = bytes.fromhex("01 B9 14 06")
RECORD_SUFFIX = bytes.fromhex("00 04 47 6F")


class TerrainConfigError(Exception):
    pass


def parse_bool(value: str) -> bool:
    normalized = value.strip().lower()
    if normalized in {"true", "yes", "1"}:
        return True
    if normalized in {"false", "no", "0"}:
        return False
    raise TerrainConfigError(f"Invalid boolean value: {value}")


def parse_hex_id(value: str) -> bytes:
    cleaned = value.replace(" ", "").strip()
    data = bytes.fromhex(cleaned)
    if len(data) != 5:
        raise TerrainConfigError(f"Layer id must be exactly 5 bytes: {value}")
    return data


def parse_config(text: str) -> dict:
    config = {
        "layer_ids": {},
        "randomize": {
            "seed": None,
            "replace_all": False,
            "sources": [],
            "targets": {},
        },
    }
    section = None
    subsection = None

    for raw_line in text.replace("\r\n", "\n").splitlines():
        line = raw_line.split("#", 1)[0].rstrip()
        if not line:
            continue

        indent = len(raw_line) - len(raw_line.lstrip(" "))
        stripped = line.strip()

        if indent == 0 and stripped.endswith(":"):
            section = stripped[:-1]
            subsection = None
            continue

        if section == "layer_ids" and indent == 2 and ":" in stripped:
            key, value = [part.strip() for part in stripped.split(":", 1)]
            config["layer_ids"][key] = parse_hex_id(value)
            continue

        if section == "randomize" and indent == 2 and stripped.endswith(":"):
            subsection = stripped[:-1]
            continue

        if section == "randomize" and indent == 2 and ":" in stripped:
            key, value = [part.strip() for part in stripped.split(":", 1)]
            if key == "seed":
                config["randomize"]["seed"] = value if value else None
            elif key == "replace_all":
                config["randomize"]["replace_all"] = parse_bool(value)
            else:
                raise TerrainConfigError(f"Unknown randomize setting: {key}")
            continue

        if section == "randomize" and subsection == "sources" and indent == 4 and stripped.startswith("- "):
            config["randomize"]["sources"].append(stripped[2:].strip())
            continue

        if section == "randomize" and subsection == "targets" and indent == 4 and ":" in stripped:
            key, value = [part.strip() for part in stripped.split(":", 1)]
            try:
                weight = int(value)
            except ValueError as exc:
                raise TerrainConfigError(f"Target weight must be an integer: {stripped}") from exc
            config["randomize"]["targets"][key] = weight
            continue

    if not config["layer_ids"]:
        raise TerrainConfigError("No layer_ids configured.")
    if not config["randomize"]["sources"]:
        raise TerrainConfigError("No randomize.sources configured.")
    if not config["randomize"]["targets"]:
        raise TerrainConfigError("No randomize.targets configured.")

    return config


def build_rng(seed_value: str | None) -> random.Random:
    if not seed_value:
        return random.Random()
    try:
        return random.Random(int(seed_value))
    except ValueError:
        return random.Random(seed_value)


def build_weighted_targets(targets: dict[str, int], layer_ids: dict[str, bytes]) -> list[bytes]:
    weighted: list[bytes] = []
    for name, weight in targets.items():
        if name not in layer_ids:
            raise TerrainConfigError(f"Unknown target layer: {name}")
        if weight > 0:
            weighted.extend([layer_ids[name]] * weight)

    if not weighted:
        raise TerrainConfigError("No usable targets configured.")

    return weighted


def find_layer_records(data: bytes) -> list[tuple[int, bytes]]:
    records: list[tuple[int, bytes]] = []
    cursor = 0

    while True:
        index = data.find(RECORD_PREFIX, cursor)
        if index == -1:
            break

        id_start = index + len(RECORD_PREFIX)
        layer_id = data[id_start:id_start + 5]
        suffix_start = id_start + 5
        if len(layer_id) == 5 and data[suffix_start:suffix_start + len(RECORD_SUFFIX)] == RECORD_SUFFIX:
            records.append((id_start, layer_id))

        cursor = index + 1

    return records


def apply_random_layers(data: bytes, config: dict) -> tuple[bytes, dict[str, int], dict[str, int], int]:
    layer_ids: dict[str, bytes] = config["layer_ids"]
    reverse_ids = {value: name for name, value in layer_ids.items()}
    source_names: list[str] = config["randomize"]["sources"]
    replace_all: bool = config["randomize"]["replace_all"]

    for name in source_names:
        if name not in layer_ids:
            raise TerrainConfigError(f"Unknown source layer: {name}")

    source_ids = {layer_ids[name] for name in source_names}
    weighted_targets = build_weighted_targets(config["randomize"]["targets"], layer_ids)
    rng = build_rng(config["randomize"].get("seed"))

    records = find_layer_records(data)
    if not records:
        raise TerrainConfigError("No layer records were found in the terrain file.")

    known_ids = set(layer_ids.values())
    before_counts = {name: 0 for name in layer_ids}
    after_counts = {name: 0 for name in layer_ids}
    output = bytearray(data)
    changed = 0

    for offset, layer_id in records:
        name = reverse_ids.get(layer_id)
        if name:
            before_counts[name] += 1

        should_replace = layer_id in source_ids or (replace_all and layer_id in known_ids)
        new_id = layer_id
        if should_replace:
            new_id = rng.choice(weighted_targets)
            if new_id != layer_id:
                output[offset:offset + 5] = new_id
                changed += 1

        new_name = reverse_ids.get(new_id)
        if new_name:
            after_counts[new_name] += 1

    return bytes(output), before_counts, after_counts, changed


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
    if not CONFIG_PATH.exists():
        print(f"apply_terrain_config.yml not found: {CONFIG_PATH}")
        return 1

    try:
        config = parse_config(CONFIG_PATH.read_text(encoding="utf-8"))
        original = terrain_path.read_bytes()
        updated, before_counts, after_counts, changed = apply_random_layers(original, config)
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
    return 0


if __name__ == "__main__":
    sys.exit(main())
