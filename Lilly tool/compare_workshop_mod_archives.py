from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath


DEFAULT_MODS_ROOT = Path(r"Y:\SteamLibrary\steamapps\common\Riftbreaker 1849580\mods")
DEFAULT_WORKSHOP_ROOT = Path(r"Y:\SteamLibrary\steamapps\workshop\content\780310")
GUID_PATTERN = re.compile(r"^\{[0-9A-Fa-f-]{36}\}$")
CHUNK_SIZE = 1024 * 1024
DEFAULT_IGNORE_PATTERNS = (
    "*.bak",
    "*.bak1",
    "*.bak2",
    "*.bak3",
    "*.grepwinreplaced",
    "__pycache__/**",
    "grepwin_backup/**",
    "**/grepwin_backup/**",
)


@dataclass
class ComparisonResult:
    mod_dir: Path
    manifest_guid: str
    zip_path: Path | None = None
    steam_published_file: str | None = None
    issues: list[str] = field(default_factory=list)
    missing_in_zip: list[str] = field(default_factory=list)
    missing_in_folder: list[str] = field(default_factory=list)
    changed_files: list[str] = field(default_factory=list)

    @property
    def is_match(self) -> bool:
        return (
            not self.issues
            and not self.missing_in_zip
            and not self.missing_in_folder
            and not self.changed_files
        )

    @property
    def has_missing_workshop_zip(self) -> bool:
        return any(issue.startswith("No workshop zip found") for issue in self.issues)

    @property
    def has_content_difference(self) -> bool:
        return (
            bool(self.zip_path)
            and (
                bool(self.issues)
                or bool(self.missing_in_zip)
                or bool(self.missing_in_folder)
                or bool(self.changed_files)
            )
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Compare each mod folder under the Riftbreaker mods directory with the workshop zip "
            "that has the same manifest GUID."
        )
    )
    parser.add_argument(
        "--mods-root",
        type=Path,
        default=DEFAULT_MODS_ROOT,
        help=f"Path to the local mods root. Default: {DEFAULT_MODS_ROOT}",
    )
    parser.add_argument(
        "--workshop-root",
        type=Path,
        default=DEFAULT_WORKSHOP_ROOT,
        help=f"Path to the workshop content root. Default: {DEFAULT_WORKSHOP_ROOT}",
    )
    parser.add_argument(
        "--show-matches",
        action="store_true",
        help="Print folders that are identical as well as folders with differences.",
    )
    parser.add_argument(
        "--ignore-glob",
        action="append",
        default=[],
        help="Ignore files matching this glob. Can be used more than once.",
    )
    parser.add_argument(
        "--no-default-ignores",
        action="store_true",
        help="Do not ignore common backup/temp files such as *.bak or grepwin_backup/**.",
    )
    parser.add_argument(
        "--list-missing-only",
        action="store_true",
        help="Print only mod folder names that do not have a matching workshop zip.",
    )
    parser.add_argument(
        "--list-different-only",
        action="store_true",
        help="Print only mod folder names that have a workshop zip but different contents.",
    )
    parser.add_argument(
        "--list-different-with-files",
        action="store_true",
        help="Print each changed mod folder name and the differing file paths under it.",
    )
    return parser.parse_args()


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(CHUNK_SIZE)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def hash_zip_entry(archive: zipfile.ZipFile, entry: zipfile.ZipInfo) -> str:
    digest = hashlib.sha256()
    with archive.open(entry, "r") as handle:
        while True:
            chunk = handle.read(CHUNK_SIZE)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def normalize_relative_path(relative_path: str) -> str:
    return PurePosixPath(relative_path.replace("\\", "/")).as_posix().lower()


def should_ignore(relative_path: str, ignore_patterns: tuple[str, ...]) -> bool:
    path = PurePosixPath(relative_path)
    return any(path.match(pattern.lower()) for pattern in ignore_patterns)


def parse_manifest_text(text: str) -> dict[str, str]:
    data: dict[str, str] = {}

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line in {"WorkspaceManifest", "{", "}"}:
            continue

        if " " not in line:
            continue

        key, value = line.split(" ", 1)
        data[key] = value.strip().strip('"')

    return data


def find_manifest_files(mod_dir: Path) -> list[Path]:
    return sorted(path for path in mod_dir.glob("*.manifest") if GUID_PATTERN.match(path.stem))


def collect_mod_directories(mods_root: Path) -> list[Path]:
    mod_dirs: list[Path] = []
    for child in sorted(mods_root.iterdir(), key=lambda path: path.name.lower()):
        if child.is_dir() and find_manifest_files(child):
            mod_dirs.append(child)
    return mod_dirs


def build_workshop_zip_map(workshop_root: Path) -> dict[str, Path]:
    zip_map: dict[str, Path] = {}
    for zip_path in sorted(workshop_root.rglob("*.zip")):
        if not GUID_PATTERN.match(zip_path.stem):
            continue

        guid = zip_path.stem.upper()
        if guid not in zip_map:
            zip_map[guid] = zip_path
    return zip_map


def build_folder_file_map(mod_dir: Path, ignore_patterns: tuple[str, ...]) -> dict[str, Path]:
    file_map: dict[str, Path] = {}
    for path in sorted(mod_dir.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(mod_dir).as_posix()
        normalized = normalize_relative_path(relative)
        if should_ignore(normalized, ignore_patterns):
            continue
        file_map[normalized] = path
    return file_map


def build_zip_entry_map(zip_path: Path, ignore_patterns: tuple[str, ...]) -> dict[str, zipfile.ZipInfo]:
    with zipfile.ZipFile(zip_path) as archive:
        entry_map = {
            normalized: entry
            for entry in archive.infolist()
            if not entry.is_dir()
            for normalized in [normalize_relative_path(entry.filename)]
            if not should_ignore(normalized, ignore_patterns)
        }
    return entry_map


def compare_mod_directory(
    mod_dir: Path, workshop_zip_map: dict[str, Path], ignore_patterns: tuple[str, ...]
) -> ComparisonResult:
    manifest_files = find_manifest_files(mod_dir)
    if not manifest_files:
        return ComparisonResult(mod_dir=mod_dir, manifest_guid="", issues=["No GUID manifest found."])

    if len(manifest_files) > 1:
        return ComparisonResult(
            mod_dir=mod_dir,
            manifest_guid=manifest_files[0].stem.upper(),
            issues=["Multiple GUID manifest files found."],
        )

    manifest_path = manifest_files[0]
    manifest_guid = manifest_path.stem.upper()
    result = ComparisonResult(mod_dir=mod_dir, manifest_guid=manifest_guid)

    try:
        manifest_data = parse_manifest_text(manifest_path.read_text(encoding="utf-8", errors="replace"))
    except OSError as exc:
        result.issues.append(f"Failed to read manifest: {exc}")
        return result

    steam_published_file = manifest_data.get("steam_published_file")
    result.steam_published_file = steam_published_file

    zip_path = workshop_zip_map.get(manifest_guid)
    if zip_path is None:
        result.issues.append(f"No workshop zip found for {manifest_guid}.")
        return result

    result.zip_path = zip_path

    workshop_item_dir = zip_path.parent.name
    if steam_published_file and steam_published_file != "0" and workshop_item_dir != steam_published_file:
        result.issues.append(
            f"Manifest steam_published_file={steam_published_file}, but zip is under workshop item {workshop_item_dir}."
        )

    folder_files = build_folder_file_map(mod_dir, ignore_patterns)
    try:
        zip_entries = build_zip_entry_map(zip_path, ignore_patterns)
    except (OSError, zipfile.BadZipFile) as exc:
        result.issues.append(f"Failed to read zip: {exc}")
        return result

    folder_keys = set(folder_files)
    zip_keys = set(zip_entries)

    result.missing_in_zip = sorted(path for path in folder_keys - zip_keys)
    result.missing_in_folder = sorted(path for path in zip_keys - folder_keys)

    shared_keys = sorted(folder_keys & zip_keys)
    if not shared_keys:
        return result

    try:
        with zipfile.ZipFile(zip_path) as archive:
            for relative_path in shared_keys:
                folder_hash = hash_file(folder_files[relative_path])
                zip_hash = hash_zip_entry(archive, zip_entries[relative_path])
                if folder_hash != zip_hash:
                    result.changed_files.append(relative_path)
    except (OSError, zipfile.BadZipFile) as exc:
        result.issues.append(f"Failed during content comparison: {exc}")

    return result


def print_result(result: ComparisonResult) -> None:
    label = "[MATCH]" if result.is_match else "[DIFF]"
    print(f"{label} {result.mod_dir.name}")
    print(f"  GUID: {result.manifest_guid}")
    if result.steam_published_file:
        print(f"  steam_published_file: {result.steam_published_file}")
    if result.zip_path is not None:
        print(f"  workshop zip: {result.zip_path}")

    for issue in result.issues:
        print(f"  issue: {issue}")
    for relative_path in result.missing_in_zip:
        print(f"  missing in zip: {relative_path}")
    for relative_path in result.missing_in_folder:
        print(f"  missing in folder: {relative_path}")
    for relative_path in result.changed_files:
        print(f"  changed: {relative_path}")


def print_different_with_files(results: list[ComparisonResult]) -> None:
    for result in results:
        print(result.mod_dir.name)

        for issue in result.issues:
            print(f"  issue: {issue}")
        for relative_path in result.missing_in_zip:
            print(f"  missing in zip: {relative_path}")
        for relative_path in result.missing_in_folder:
            print(f"  missing in folder: {relative_path}")
        for relative_path in result.changed_files:
            print(f"  changed: {relative_path}")

        print()


def main() -> int:
    args = parse_args()
    mods_root = args.mods_root.resolve()
    workshop_root = args.workshop_root.resolve()
    ignore_patterns = tuple(
        pattern.lower()
        for pattern in (() if args.no_default_ignores else DEFAULT_IGNORE_PATTERNS) + tuple(args.ignore_glob)
    )

    if not mods_root.exists():
        print(f"Mods root not found: {mods_root}")
        return 1
    if not workshop_root.exists():
        print(f"Workshop root not found: {workshop_root}")
        return 1

    mod_dirs = collect_mod_directories(mods_root)
    if not mod_dirs:
        print(f"No mod folders with GUID manifests found under: {mods_root}")
        return 1

    workshop_zip_map = build_workshop_zip_map(workshop_root)
    if not workshop_zip_map:
        print(f"No workshop zip files with GUID names found under: {workshop_root}")
        return 1

    results = [compare_mod_directory(mod_dir, workshop_zip_map, ignore_patterns) for mod_dir in mod_dirs]
    mismatches = [result for result in results if not result.is_match]
    missing_zip_results = [result for result in results if result.has_missing_workshop_zip]
    different_results = [result for result in results if result.has_content_difference]

    if args.list_missing_only and args.list_different_only:
        for result in mismatches:
            print(result.mod_dir.name)
        return 0 if not mismatches else 2

    if args.list_missing_only:
        for result in missing_zip_results:
            print(result.mod_dir.name)
        return 0 if not missing_zip_results else 2

    if args.list_different_only:
        for result in different_results:
            print(result.mod_dir.name)
        return 0 if not different_results else 2

    if args.list_different_with_files:
        print_different_with_files(different_results)
        return 0 if not different_results else 2

    for result in results:
        if args.show_matches or not result.is_match:
            print_result(result)
            print()

    print(f"Checked {len(results)} mod folder(s).")
    print(f"Matches: {len(results) - len(mismatches)}")
    print(f"Differences: {len(mismatches)}")

    return 0 if not mismatches else 2


if __name__ == "__main__":
    sys.exit(main())
