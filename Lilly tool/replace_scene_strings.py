from __future__ import annotations

import random
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = ROOT_DIR / "replace_scene_strings.yml"
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


class ReplaceConfigError(Exception):
    pass


def load_config() -> dict:
    if yaml is None:
        raise ReplaceConfigError(f"PyYAML is required to read {CONFIG_PATH.name}: {YAML_IMPORT_ERROR}")

    if not CONFIG_PATH.exists():
        raise ReplaceConfigError(f"Config file not found: {CONFIG_PATH}")

    try:
        config = yaml.safe_load(CONFIG_PATH.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as exc:
        raise ReplaceConfigError(f"Invalid YAML in {CONFIG_PATH.name}: {exc}") from exc

    if not isinstance(config, dict):
        raise ReplaceConfigError(f"{CONFIG_PATH.name} must contain a top-level mapping.")

    rules = config.get("rules")
    if not isinstance(rules, list) or not rules:
        raise ReplaceConfigError("rules must be a non-empty list.")

    return config


def resolve_root_dir(config: dict) -> Path:
    root_dir = config.get("root_dir")
    if not isinstance(root_dir, str) or not root_dir.strip():
        raise ReplaceConfigError("root_dir must be a non-empty string.")

    resolved = (ROOT_DIR / root_dir).resolve()
    if not resolved.exists():
        raise ReplaceConfigError(f"root_dir does not exist: {resolved}")
    return resolved


def choose_replacement(rule: dict) -> str:
    replacements = rule.get("replacements")
    if not isinstance(replacements, list) or not replacements:
        raise ReplaceConfigError(f"rule '{rule.get('name', 'unnamed')}' must define replacements.")

    normalized = [str(item) for item in replacements if str(item)]
    if not normalized:
        raise ReplaceConfigError(f"rule '{rule.get('name', 'unnamed')}' replacements are empty.")

    mode = str(rule.get("replacement_mode", "random")).strip().lower()
    if mode == "first":
        return normalized[0]
    if mode == "random":
        return random.choice(normalized)

    raise ReplaceConfigError(f"unsupported replacement_mode '{mode}' in rule '{rule.get('name', 'unnamed')}'.")


def apply_rule(text: str, rule: dict) -> tuple[str, int]:
    targets = rule.get("targets")
    if not isinstance(targets, list) or not targets:
        raise ReplaceConfigError(f"rule '{rule.get('name', 'unnamed')}' must define targets.")

    updated = text
    replace_count = 0
    for target in targets:
        source = str(target)
        if not source:
            continue

        occurrences = updated.count(source)
        if occurrences == 0:
            continue

        for _ in range(occurrences):
            updated = updated.replace(source, choose_replacement(rule), 1)
        replace_count += occurrences

    return updated, replace_count


def build_backup_path(scene_path: Path, backup_suffix: str) -> Path:
    base_candidate = Path(str(scene_path) + backup_suffix)
    if not base_candidate.exists():
        return base_candidate

    index = 1
    while True:
        candidate = Path(str(scene_path) + backup_suffix + str(index))
        if not candidate.exists():
            return candidate
        index += 1


def main() -> int:
    try:
        config = load_config()
        root_dir = resolve_root_dir(config)
    except ReplaceConfigError as exc:
        print(f"Error: {exc}")
        return 1

    random_seed = config.get("random_seed")
    if random_seed not in (None, ""):
        random.seed(random_seed)

    file_glob = str(config.get("file_glob", "**/*.scene"))
    encoding = str(config.get("encoding", "utf-8"))
    create_backup = bool(config.get("create_backup", True))
    backup_suffix = str(config.get("backup_suffix", ".bak"))
    rules = config["rules"]

    scene_paths = sorted(path for path in root_dir.glob(file_glob) if path.is_file())
    if not scene_paths:
        print(f"No files matched: {root_dir} / {file_glob}")
        return 1

    changed_files = 0
    total_replacements = 0

    for scene_path in scene_paths:
        original_text = scene_path.read_text(encoding=encoding)
        updated_text = original_text
        file_replacements = 0

        for rule in rules:
            updated_text, replace_count = apply_rule(updated_text, rule)
            file_replacements += replace_count

        if file_replacements == 0:
            continue

        if create_backup:
            backup_path = build_backup_path(scene_path, backup_suffix)
            backup_path.write_text(original_text, encoding=encoding, newline="")

        scene_path.write_text(updated_text, encoding=encoding, newline="")
        changed_files += 1
        total_replacements += file_replacements
        print(f"Updated: {scene_path} (replacements: {file_replacements})")

    print(f"Done. changed_files={changed_files} total_replacements={total_replacements}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
