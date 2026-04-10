from __future__ import annotations

import copy
import random
import re
import sys
from collections import OrderedDict
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = ROOT_DIR / "apply_scene_config.yml"
VENDOR_DIR = ROOT_DIR / "_vendor"

if VENDOR_DIR.exists():
    sys.path.insert(0, str(VENDOR_DIR))

try:
    import yaml
except ModuleNotFoundError as exc:
    yaml = None
    YAML_IMPORT_ERROR = exc
else:
    YAML_IMPORT_ERROR = None


class SceneConfigError(Exception):
    pass


def normalize_number(value: object) -> str:
    if isinstance(value, str):
        return value.strip().strip('"').strip("'")
    if isinstance(value, bool):
        raise SceneConfigError(f"numeric value is invalid: {value}")
    return str(value)


def parse_sequence(value: object, expected_length: int | None = None, field_name: str = "value") -> list[object]:
    if isinstance(value, str):
        parts = [part.strip() for part in value.split(",")]
    elif isinstance(value, (list, tuple)):
        parts = list(value)
    else:
        raise SceneConfigError(f"{field_name} must be a comma string or YAML list: {value}")

    if expected_length is not None and len(parts) != expected_length:
        raise SceneConfigError(f"{field_name} must contain exactly {expected_length} values: {value}")

    return parts


def parse_vector(value: object) -> OrderedDict[str, str]:
    parts = parse_sequence(value, expected_length=3, field_name="vector")
    return OrderedDict((axis, normalize_number(part)) for axis, part in zip(("x", "y", "z"), parts))


def parse_scale(value: object) -> OrderedDict[str, str | tuple[float, float]]:
    parts = parse_sequence(value, expected_length=3, field_name="scale")
    scale = OrderedDict()
    for axis, part in zip(("x", "y", "z"), parts):
        scale[axis] = parse_scale_axis(part, axis)
    return scale


def parse_scale_axis(value: object, axis: str) -> str | tuple[float, float]:
    if isinstance(value, (list, tuple)):
        if len(value) != 2:
            raise SceneConfigError(f"scale {axis} range must contain exactly 2 values: {value}")
        min_value = parse_float_number(value[0], f"scale {axis} minimum")
        max_value = parse_float_number(value[1], f"scale {axis} maximum")
        if min_value > max_value:
            raise SceneConfigError(f"scale {axis} range is invalid: {value}")
        return min_value, max_value

    normalize_number(value)
    return normalize_number(value)


def parse_float_number(value: object, field_name: str) -> float:
    normalized = normalize_number(value)
    try:
        return float(normalized)
    except ValueError as exc:
        raise SceneConfigError(f"{field_name} must be a number: {value}") from exc


def parse_position(value: object) -> OrderedDict[str, str]:
    parts = parse_sequence(value, field_name="position")
    if len(parts) == 2:
        return OrderedDict((("x", normalize_number(parts[0])), ("z", normalize_number(parts[1]))))
    if len(parts) == 3:
        return OrderedDict(
            (
                ("x", normalize_number(parts[0])),
                ("y", normalize_number(parts[1])),
                ("z", normalize_number(parts[2])),
            )
        )
    raise SceneConfigError(f"position must be [x, z] or [x, y, z]: {value}")


def parse_grid_point(value: object) -> tuple[str, str]:
    parts = parse_sequence(value, expected_length=2, field_name="grid coordinate")
    return normalize_number(parts[0]), normalize_number(parts[1])


def parse_grid_y(value: object) -> str:
    normalized = normalize_number(value)
    if not normalized:
        raise SceneConfigError("grid y must not be empty.")
    return normalized


def float_to_scene_number(value: float) -> str:
    if value.is_integer():
        return str(int(value))
    return f"{value:.6f}".rstrip("0").rstrip(".")


def parse_random_count(value: object) -> int:
    normalized = normalize_number(value)
    try:
        count = int(normalized)
    except ValueError as exc:
        raise SceneConfigError(f"random count must be an integer: {value}") from exc

    if count < 0:
        raise SceneConfigError("random count must be zero or greater.")

    return count


def parse_random_count_range(value: object) -> int | tuple[int, int]:
    if isinstance(value, (list, tuple)):
        if len(value) != 2:
            raise SceneConfigError(f"random_count range must contain exactly 2 values: {value}")

        min_count = parse_random_count(value[0])
        max_count = parse_random_count(value[1])
        if min_count > max_count:
            raise SceneConfigError(f"random_count range is invalid: {value}")
        return min_count, max_count

    return parse_random_count(value)


def expand_grid_positions(grid: dict) -> list[str]:
    min_x_str, min_z_str = parse_grid_point(grid["min"])
    max_x_str, max_z_str = parse_grid_point(grid["max"])
    step_x_str, step_z_str = parse_grid_point(grid["step"])
    y_str = grid.get("y")

    min_x = float(min_x_str)
    min_z = float(min_z_str)
    max_x = float(max_x_str)
    max_z = float(max_z_str)
    step_x = float(step_x_str)
    step_z = float(step_z_str)

    if step_x <= 0 or step_z <= 0:
        raise SceneConfigError("grid step must be greater than zero.")
    if min_x > max_x or min_z > max_z:
        raise SceneConfigError("grid min/max range is invalid.")

    positions: list[str] = []
    z = min_z
    while z <= max_z + 1e-9:
        x = min_x
        while x <= max_x + 1e-9:
            if y_str is None:
                positions.append(f"{float_to_scene_number(x)},{float_to_scene_number(z)}")
            else:
                positions.append(f"{float_to_scene_number(x)},{y_str},{float_to_scene_number(z)}")
            x += step_x
        z += step_z

    return positions


def resolve_random_count(random_count: int | tuple[int, int] | None, max_count: int) -> int | None:
    if random_count is None:
        return None
    if isinstance(random_count, tuple):
        min_count, max_range_count = random_count
        if min_count > max_count:
            raise SceneConfigError(
                f"random_count minimum {min_count} is greater than available grid positions {max_count}."
            )
        return random.randint(min_count, min(max_range_count, max_count))
    return random_count


def format_position_value(value: object) -> str:
    parts = parse_sequence(value, field_name="position")
    if len(parts) not in {2, 3}:
        raise SceneConfigError(f"position must be [x, z] or [x, y, z]: {value}")
    return ",".join(normalize_number(part) for part in parts)


def resolve_scale(scale: OrderedDict[str, str | tuple[float, float]]) -> OrderedDict[str, str]:
    resolved = OrderedDict()
    for axis, value in scale.items():
        if isinstance(value, tuple):
            resolved[axis] = float_to_scene_number(random.uniform(value[0], value[1]))
        else:
            resolved[axis] = value
    return resolved


def parse_config(config_text: str) -> tuple[dict, list[dict]]:
    if yaml is None:
        raise SceneConfigError(f"PyYAML is required to read {CONFIG_PATH.name}: {YAML_IMPORT_ERROR}")

    try:
        config = yaml.safe_load(config_text) or {}
    except yaml.YAMLError as exc:
        raise SceneConfigError(f"invalid YAML in {CONFIG_PATH.name}: {exc}") from exc

    if not isinstance(config, dict):
        raise SceneConfigError(f"{CONFIG_PATH.name} must contain a top-level mapping.")

    template_text = config.get("entity_template", config.get("EntityTemplate"))
    if not isinstance(template_text, str) or not template_text.strip():
        raise SceneConfigError(f"{CONFIG_PATH.name} must define a non-empty entity_template block.")

    template = parse_entity_template_text(template_text.strip())

    rules_source = config.get("rules")
    if rules_source is None:
        rules_source = {
            key: value
            for key, value in config.items()
            if key not in {"entity_template", "EntityTemplate"}
        }

    if not isinstance(rules_source, dict):
        raise SceneConfigError("rules must be a mapping of rule id to rule settings.")

    rules: list[dict] = []
    for rule_id, raw_rule in rules_source.items():
        if not isinstance(raw_rule, dict):
            raise SceneConfigError(f"rule '{rule_id}' must be a mapping.")

        base_blueprints = raw_rule.get("base_blueprints", raw_rule.get("base_blueprint", []))
        if isinstance(base_blueprints, str):
            base_blueprints = [base_blueprints]
        if not isinstance(base_blueprints, list):
            raise SceneConfigError(f"rule '{rule_id}' base_blueprints must be a list.")

        transform_source = raw_rule.get("transform_groups", raw_rule.get("TransformComponent", []))
        if transform_source is None:
            transform_source = []
        if not isinstance(transform_source, list):
            raise SceneConfigError(f"rule '{rule_id}' transform_groups must be a list.")

        rule = {
            "id": str(rule_id),
            "base_blueprints": [str(blueprint).strip() for blueprint in base_blueprints if str(blueprint).strip()],
            "all_delete": bool(raw_rule.get("all_delete", raw_rule.get("all delete", False))),
            "skip_existing": bool(raw_rule.get("skip_existing", False)),
            "transform_groups": [],
        }

        for index, transform_data in enumerate(transform_source, start=1):
            if not isinstance(transform_data, dict):
                raise SceneConfigError(f"rule '{rule_id}' transform group {index} must be a mapping.")

            transform_group: dict = {}
            if "scale" in transform_data:
                transform_group["scale"] = parse_scale(transform_data["scale"])

            if "position" in transform_data:
                positions_data = transform_data["position"]
                if not isinstance(positions_data, list):
                    raise SceneConfigError(f"rule '{rule_id}' position must be a list.")
                transform_group["position"] = [format_position_value(position) for position in positions_data]

            if "grid" in transform_data:
                grid_data = transform_data["grid"]
                if not isinstance(grid_data, dict):
                    raise SceneConfigError(f"rule '{rule_id}' grid must be a mapping.")

                grid: dict = {}
                for key in ("min", "max", "step"):
                    if key not in grid_data:
                        raise SceneConfigError(f"rule '{rule_id}' grid is missing '{key}'.")
                    grid[key] = grid_data[key]

                if "y" in grid_data:
                    grid["y"] = parse_grid_y(grid_data["y"])

                transform_group["grid"] = grid

                random_count_value = grid_data.get("random_count", grid_data.get("random count"))
                if random_count_value is not None:
                    transform_group["grid_random_count"] = parse_random_count_range(random_count_value)

            rule["transform_groups"].append(transform_group)

        rules.append(rule)

    for rule in rules:
        for transform_group in rule["transform_groups"]:
            grid = transform_group.get("grid")
            if not grid:
                continue

            positions = transform_group.setdefault("position", [])
            grid_positions = expand_grid_positions(grid)
            random_count = resolve_random_count(transform_group.get("grid_random_count"), len(grid_positions))
            if random_count is not None and random_count < len(grid_positions):
                grid_positions = random.sample(grid_positions, random_count)
            positions.extend(grid_positions)

    if not rules:
        raise SceneConfigError(f"{CONFIG_PATH.name} does not contain any rules.")

    return template, rules


def parse_scene(scene_text: str) -> tuple[int, list[dict]]:
    scene_text = scene_text.replace("\r\n", "\n")
    count_match = re.search(r'^entity_count\s+"(\d+)"', scene_text, re.MULTILINE)

    entities: list[dict] = []
    pos = count_match.end() if count_match else 0

    while pos < len(scene_text):
        while pos < len(scene_text) and scene_text[pos].isspace():
            pos += 1
        if pos >= len(scene_text):
            break

        editor_index = None
        if scene_text.startswith("//editor", pos):
            line_end = scene_text.find("\n", pos)
            if line_end == -1:
                line_end = len(scene_text)
            editor_line = scene_text[pos:line_end]
            editor_match = re.search(r'index\((\d+)\)', editor_line)
            if editor_match:
                editor_index = int(editor_match.group(1))
            pos = line_end + 1
            while pos < len(scene_text) and scene_text[pos].isspace():
                pos += 1

        if not scene_text.startswith("EntityTemplate", pos):
            raise SceneConfigError("scene parsing failed: expected EntityTemplate block.")

        block_end = find_block_end(scene_text, pos + len("EntityTemplate"))
        block_text = scene_text[pos:block_end]
        entity = parse_entity_template_text(block_text)
        entity["editor_index"] = editor_index
        entities.append(entity)
        pos = block_end

    return int(count_match.group(1)) if count_match else len(entities), entities


def find_block_end(text: str, search_start: int) -> int:
    brace_start = text.find("{", search_start)
    if brace_start == -1:
        raise SceneConfigError("opening brace not found.")

    depth = 0
    for index in range(brace_start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                end = index + 1
                while end < len(text) and text[end] in "\r\n\t ":
                    end += 1
                return end

    raise SceneConfigError("block closing brace was not found.")


def parse_entity_template_text(text: str) -> dict:
    text = text.replace("\r\n", "\n").strip()
    blueprint_match = re.search(r'base_blueprint\s+"([^"]+)"', text)
    blueprint = normalize_number(blueprint_match.group(1)) if blueprint_match else None

    local_aabb_block = extract_named_block(text, "LocalAabbDesc")
    transform_block = extract_named_block(text, "TransformComponent", allow_empty=True)

    return {
        "base_blueprint": blueprint,
        "local_aabb": parse_local_aabb_block(local_aabb_block) if local_aabb_block else None,
        "transform": parse_transform_block(transform_block) if transform_block is not None else OrderedDict(),
    }


def extract_named_block(text: str, name: str, allow_empty: bool = False) -> str | None:
    pattern = re.compile(rf"\b{re.escape(name)}\b")
    match = pattern.search(text)
    if not match:
        return None

    cursor = match.end()
    while cursor < len(text) and text[cursor].isspace():
        cursor += 1

    if cursor >= len(text) or text[cursor] != "{":
        if allow_empty:
            return ""
        raise SceneConfigError(f"{name} block was not found.")

    end = find_matching_brace(text, cursor)
    return text[cursor:end]


def find_matching_brace(text: str, start_index: int) -> int:
    depth = 0
    for index in range(start_index, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index + 1
    raise SceneConfigError("block closing brace was not found.")


def parse_local_aabb_block(block: str) -> dict:
    return {
        "min": parse_vector_block(extract_named_block(block, "min")),
        "max": parse_vector_block(extract_named_block(block, "max")),
    }


def parse_transform_block(block: str) -> OrderedDict[str, OrderedDict[str, str]]:
    transform = OrderedDict()
    if not block:
        return transform

    for name in ("position", "scale", "rotation", "orientation"):
        sub_block = extract_named_block(block, name)
        if sub_block:
            transform[name] = parse_vector_block(sub_block)

    return transform


def parse_vector_block(block: str | None) -> OrderedDict[str, str]:
    vector = OrderedDict()
    if not block:
        return vector

    for axis in ("x", "y", "z", "w"):
        match = re.search(rf'\b{axis}\s+"([^"]+)"', block)
        if match:
            vector[axis] = normalize_number(match.group(1))
    return vector


def build_scene(template: dict, rules: list[dict], original_entities: list[dict]) -> list[dict]:
    result_entities = [copy.deepcopy(entity) for entity in original_entities]

    for rule in rules:
        if not rule["base_blueprints"]:
            continue

        targets = set(rule["base_blueprints"])
        if rule["all_delete"]:
            result_entities = [entity for entity in result_entities if entity.get("base_blueprint") not in targets]

        for blueprint in rule["base_blueprints"]:
            if rule.get("skip_existing") and any(
                entity.get("base_blueprint") == blueprint for entity in result_entities
            ):
                continue
            for transform_group in rule["transform_groups"]:
                for position in transform_group.get("position", []):
                    entity = build_entity_from_template(template, blueprint, transform_group, position)
                    result_entities.append(entity)

    return result_entities


def build_entity_from_template(template: dict, blueprint: str, transform_group: dict, position_value: str) -> dict:
    entity = copy.deepcopy(template)
    entity["base_blueprint"] = blueprint

    defaults = entity.get("transform", OrderedDict())
    merged_transform: OrderedDict[str, OrderedDict[str, str]] = OrderedDict()

    position_defaults = copy.deepcopy(defaults.get("position", OrderedDict()))
    position_defaults.update(parse_position(position_value))
    merged_transform["position"] = position_defaults

    if "scale" in transform_group:
        scale_defaults = copy.deepcopy(defaults.get("scale", OrderedDict()))
        scale_defaults.update(resolve_scale(transform_group["scale"]))
        merged_transform["scale"] = scale_defaults
    elif "scale" in defaults:
        merged_transform["scale"] = copy.deepcopy(defaults["scale"])

    for key in ("rotation", "orientation"):
        if key in defaults:
            merged_transform[key] = copy.deepcopy(defaults[key])

    entity["transform"] = merged_transform
    entity.pop("editor_index", None)
    return entity


def format_scene(entities: list[dict]) -> str:
    max_existing_index = max((entity.get("editor_index") or 0 for entity in entities), default=0)
    next_editor_index = max_existing_index + 1

    lines = [f'entity_count "{len(entities)}"']
    for entity in entities:
        editor_index = entity.get("editor_index")
        if editor_index is None:
            editor_index = next_editor_index
            next_editor_index += 1

        lines.append(f'//editor "index({editor_index})"')
        lines.extend(format_entity(entity))
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def format_entity(entity: dict) -> list[str]:
    lines = ["EntityTemplate", "{"]

    if entity.get("base_blueprint"):
        lines.append(f'\tbase_blueprint "{entity["base_blueprint"]}"')

    lines.append("\tcomponents")
    lines.append("\t{")

    if entity.get("local_aabb"):
        lines.extend(format_local_aabb(entity["local_aabb"]))

    lines.extend(format_transform(entity.get("transform", OrderedDict()), template_transform=entity.get("_template_transform")))
    lines.append("\t}")
    lines.append("}")
    return lines


def format_local_aabb(local_aabb: dict) -> list[str]:
    lines = [
        "\t\tLocalAabbDesc",
        "\t\t{",
        "\t\t\tlocal_aabb",
        "\t\t\t{",
    ]
    lines.extend(format_vector_named_block("min", local_aabb["min"], "\t\t\t\t"))
    lines.append("")
    lines.extend(format_vector_named_block("max", local_aabb["max"], "\t\t\t\t"))
    lines.append("\t\t\t}")
    lines.append("\t\t}")
    lines.append("")
    return lines


def format_transform(
    transform: OrderedDict[str, OrderedDict[str, str]],
    template_transform: OrderedDict[str, OrderedDict[str, str]] | None = None,
) -> list[str]:
    template_transform = template_transform or OrderedDict()
    content: list[str] = ["\t\tTransformComponent"]
    property_blocks: list[list[str]] = []

    for key in ("position", "scale", "rotation", "orientation"):
        values = transform.get(key)
        if not values:
            continue

        default_values = template_transform.get(key, OrderedDict())
        diff_values = OrderedDict((axis, value) for axis, value in values.items() if default_values.get(axis) != value)
        if not diff_values:
            continue

        property_blocks.append(format_vector_named_block(key, diff_values, "\t\t\t"))

    if not property_blocks:
        content.append("\t\t{")
        content.append("\t\t}")
        return content

    content.append("\t\t{")
    for index, block in enumerate(property_blocks):
        if index > 0:
            content.append("")
        content.extend(block)
    content.append("\t\t}")
    return content


def format_vector_named_block(name: str, values: OrderedDict[str, str], indent: str) -> list[str]:
    lines = [f"{indent}{name}", f"{indent}" + "{"]
    for axis, value in values.items():
        lines.append(f'{indent}\t{axis} "{value}"')
    lines.append(f"{indent}" + "}")
    return lines


def attach_template_defaults(entities: list[dict], template_transform: OrderedDict[str, OrderedDict[str, str]]) -> None:
    for entity in entities:
        entity["_template_transform"] = template_transform


def build_backup_path(scene_path: Path) -> Path:
    backup_path = scene_path.with_suffix(scene_path.suffix + ".bak")
    if not backup_path.exists():
        return backup_path

    index = 1
    while True:
        candidate = scene_path.with_suffix(scene_path.suffix + f".bak{index}")
        if not candidate.exists():
            return candidate
        index += 1


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: scene_apply_config.py <scene file>")
        return 1

    scene_path = Path(sys.argv[1]).resolve()
    if not scene_path.exists():
        print(f"File not found: {scene_path}")
        return 1
    if scene_path.suffix.lower() != ".scene":
        print(f"Only .scene files are supported: {scene_path}")
        return 1
    if not CONFIG_PATH.exists():
        print(f"Config file not found: {CONFIG_PATH}")
        return 1

    try:
        template, rules = parse_config(CONFIG_PATH.read_text(encoding="utf-8"))
        original_text = scene_path.read_text(encoding="utf-8")
        _, original_entities = parse_scene(original_text)
        updated_entities = build_scene(template, rules, original_entities)
        attach_template_defaults(updated_entities, template.get("transform", OrderedDict()))
        backup_path = build_backup_path(scene_path)
        backup_path.write_text(original_text, encoding="utf-8", newline="\n")
        scene_path.write_text(format_scene(updated_entities), encoding="utf-8", newline="\n")
    except SceneConfigError as exc:
        print(f"Error: {exc}")
        return 1

    print(f"Updated: {scene_path}")
    print(f"Backup created: {backup_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
