from __future__ import annotations

import copy
import random
import re
import sys
from collections import OrderedDict
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = ROOT_DIR / "apply_scene_config.yml"


class SceneConfigError(Exception):
    pass


def parse_vector(value: str) -> OrderedDict[str, str]:
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 3:
        raise SceneConfigError(f"3축 값이 필요합니다: {value}")
    return OrderedDict((axis, normalize_number(part)) for axis, part in zip(("x", "y", "z"), parts))


def parse_position(value: str) -> OrderedDict[str, str]:
    parts = [part.strip() for part in value.split(",")]
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
    raise SceneConfigError(f"position은 x,z 또는 x,y,z 형식이어야 합니다: {value}")


def parse_grid_point(value: str) -> tuple[str, str]:
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 2:
        raise SceneConfigError(f"grid coordinate must be x,z: {value}")
    return normalize_number(parts[0]), normalize_number(parts[1])


def normalize_number(value: str) -> str:
    return value.strip().strip('"').strip("'")


def float_to_scene_number(value: float) -> str:
    if value.is_integer():
        return str(int(value))
    return f"{value:.6f}".rstrip("0").rstrip(".")


def parse_random_count(value: str) -> int:
    normalized = normalize_number(value)
    try:
        count = int(normalized)
    except ValueError as exc:
        raise SceneConfigError(f"random count must be an integer: {value}") from exc

    if count < 0:
        raise SceneConfigError("random count must be zero or greater.")

    return count


def expand_grid_positions(grid: dict) -> list[str]:
    min_x_str, min_z_str = parse_grid_point(grid["min"])
    max_x_str, max_z_str = parse_grid_point(grid["max"])
    step_x_str, step_z_str = parse_grid_point(grid["step"])

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
            positions.append(f"{float_to_scene_number(x)},{float_to_scene_number(z)}")
            x += step_x
        z += step_z

    return positions


def parse_config(config_text: str) -> tuple[dict, list[dict]]:
    config_text = config_text.replace("\r\n", "\n")
    template_match = re.search(r"EntityTemplate:\s*'(?P<body>.*?)'\s*(?:\n\d+:|\Z)", config_text, re.DOTALL)
    if not template_match:
        raise SceneConfigError("config.yml에서 EntityTemplate를 찾지 못했습니다.")

    template_body = template_match.group("body").strip("\n")
    template = parse_entity_template_text("EntityTemplate\n" + template_body)

    rules_text = config_text[template_match.end() - 2 :]
    rules: list[dict] = []
    current_rule: dict | None = None
    current_transform: dict | None = None
    current_positions: list[str] | None = None

    for raw_line in rules_text.splitlines():
        if not raw_line.strip():
            continue

        line = raw_line.split("#", 1)[0].rstrip()
        if not line:
            continue

        indent = len(raw_line) - len(raw_line.lstrip(" "))
        stripped = line.strip()

        top_match = indent == 0 and re.match(r"^([^\s:#][^:]*)\s*:\s*$", stripped)
        if top_match:
            current_rule = {
                "id": top_match.group(1).strip(),
                "base_blueprints": [],
                "all_delete": False,
                "transform_groups": [],
            }
            rules.append(current_rule)
            current_transform = None
            current_positions = None
            continue

        if current_rule is None:
            continue

        if indent == 2 and stripped == "base_blueprint:":
            continue

        if indent == 4 and stripped.startswith("- "):
            current_rule["base_blueprints"].append(stripped[2:].strip())
            continue

        if indent == 2 and stripped.startswith("all delete:"):
            current_rule["all_delete"] = stripped.split(":", 1)[1].strip().lower() == "true"
            continue

        if indent == 2 and stripped == "TransformComponent:":
            continue

        if indent == 4 and stripped == "-":
            current_transform = {}
            current_rule["transform_groups"].append(current_transform)
            current_positions = None
            continue

        if current_transform is None:
            continue

        if indent == 6 and stripped.startswith("scale:"):
            current_transform["scale"] = parse_vector(stripped.split(":", 1)[1].strip())
            current_positions = None
            continue

        if indent == 6 and stripped == "position:":
            current_positions = []
            current_transform["position"] = current_positions
            continue

        if indent == 6 and stripped == "grid:":
            current_transform["grid"] = {}
            current_positions = None
            continue

        if indent == 8 and current_transform.get("grid") is not None and ":" in stripped:
            key, raw_value = [part.strip() for part in stripped.split(":", 1)]
            if key in {"min", "max", "step"} and raw_value:
                current_transform["grid"][key] = raw_value
                continue
            if key == "random count" and raw_value:
                current_transform["grid_random_count"] = parse_random_count(raw_value)
                continue

        if indent == 8 and stripped.startswith("- ") and current_positions is not None:
            current_positions.append(stripped[2:].strip())
            continue

    for rule in rules:
        for transform_group in rule["transform_groups"]:
            grid = transform_group.get("grid")
            if not grid:
                continue

            missing = [key for key in ("min", "max", "step") if key not in grid]
            if missing:
                raise SceneConfigError(f"grid settings are missing: {', '.join(missing)}")

            positions = transform_group.setdefault("position", [])
            grid_positions = expand_grid_positions(grid)
            random_count = transform_group.get("grid_random_count")
            if random_count is not None and random_count < len(grid_positions):
                grid_positions = random.sample(grid_positions, random_count)
            positions.extend(grid_positions)

    if not rules:
        raise SceneConfigError("config.yml에서 적용 규칙을 찾지 못했습니다.")

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
            raise SceneConfigError("scene 파일 파싱 중 EntityTemplate 시작 위치를 찾지 못했습니다.")

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
        raise SceneConfigError("중괄호 시작을 찾지 못했습니다.")

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

    raise SceneConfigError("중괄호가 닫히지 않았습니다.")


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
        raise SceneConfigError(f"{name} 블록을 찾지 못했습니다.")

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
    raise SceneConfigError("블록 종료 중괄호를 찾지 못했습니다.")


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
        scale_defaults.update(transform_group["scale"])
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
        print("사용법: scene_apply_config.py <scene 파일>")
        return 1

    scene_path = Path(sys.argv[1]).resolve()
    if not scene_path.exists():
        print(f"파일을 찾을 수 없습니다: {scene_path}")
        return 1
    if scene_path.suffix.lower() != ".scene":
        print(f".scene 파일만 처리할 수 있습니다: {scene_path}")
        return 1
    if not CONFIG_PATH.exists():
        print(f"config.yml을 찾을 수 없습니다: {CONFIG_PATH}")
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
        print(f"오류: {exc}")
        return 1

    print(f"수정 완료: {scene_path}")
    print(f"백업 생성: {backup_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
