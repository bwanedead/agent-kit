#!/usr/bin/env python3
"""
ralph-services: Bootstrap, validate, and update Ralph workflow infrastructure in projects.

Commands:
  --init <path>        Initialize Ralph in a project
  --update [<path>]    Update Ralph templates (preserves runs/)
  --doctor [<path>]    Validate Ralph setup
  --set-root <path>    Save canonical Ralph root to user config
  --print-root         Print resolved canonical Ralph root and source
  --help               Show help
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

# =============================================================================
# CONSTANTS
# =============================================================================

RALPH_META_FILE = ".ralph-meta.json"
DEFAULT_RALPH_ROOT = r"C:\projects\ralph"
CONFIG_DIR_NAME = "ralph"
CONFIG_FILE_NAME = "ralph-root.txt"

TEMPLATE_FILES = [
    "COMPATIBILITY_NOTES.md",
    "CONTROL_PLANE.md",
    "HOW_RALPH_WORKS.md",
    "INVOKE_RALPH.md",
    "LOOP_STATE_TEMPLATE.json",
    "PRD_JSON_SCHEMA.md",
    "PRD_JSON_TEMPLATE.json",
    "PRD_TEMPLATE.md",
    "PREP_AGENT_CHECKLIST.md",
    "PROMPT_TEMPLATE.md",
    "REVIEW_TEMPLATE.md",
    "RUN_CHECKLIST.md",
    "RUN_SKELETON.md",
    "RUN_SKELETON_CONTRACT.md",
    "STEERING_TEMPLATE.md",
    "STORY_GUIDELINES.md",
    "SUMMARY_TEMPLATE.md",
    "TRANSCRIPT_TEMPLATE.md",
    "VISION_TEMPLATE.md",
]


# =============================================================================
# DISCOVERY
# =============================================================================

def get_local_app_data() -> Path:
    """Get platform-appropriate local app data directory."""
    if sys.platform == "win32":
        return Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support"
    else:
        return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))


def get_config_file() -> Path:
    """Get path to ralph-root.txt config file."""
    return get_local_app_data() / CONFIG_DIR_NAME / CONFIG_FILE_NAME


def find_ralph_root_with_source() -> tuple[Optional[Path], str]:
    """
    Discover canonical Ralph root via (first match wins):
    1. RALPH_ROOT environment variable
    2. User config file in local app data
    3. Fallback to default path

    Returns (path, source) where source is one of: "env", "config", "fallback", "none"
    """
    # Method 1: Environment variable
    env_root = os.environ.get("RALPH_ROOT")
    if env_root:
        path = Path(env_root)
        if path.exists() and is_valid_ralph_root(path):
            return path, "env"

    # Method 2: User config file
    config_file = get_config_file()
    if config_file.exists():
        try:
            config_root = config_file.read_text().strip()
            if config_root:
                path = Path(config_root)
                if path.exists() and is_valid_ralph_root(path):
                    return path, "config"
        except Exception:
            pass

    # Method 3: Fallback to default
    default = Path(DEFAULT_RALPH_ROOT)
    if default.exists() and is_valid_ralph_root(default):
        return default, "fallback"

    return None, "none"


def find_ralph_root() -> Optional[Path]:
    """Discover canonical Ralph root. Returns path or None."""
    path, _ = find_ralph_root_with_source()
    return path


def is_valid_ralph_root(path: Path) -> bool:
    """Check if path contains valid Ralph canonical structure."""
    return (path / "templates").is_dir() and (path / "version.json").exists()


def save_ralph_root(path: Path) -> None:
    """Save Ralph root to user config file."""
    config_file = get_config_file()
    config_file.parent.mkdir(parents=True, exist_ok=True)
    config_file.write_text(str(path.resolve()))
    print(f"  Saved Ralph root to: {config_file}")


# =============================================================================
# VERSION & METADATA
# =============================================================================

def get_source_version(ralph_root: Path) -> dict:
    """Read version info from canonical Ralph root."""
    version_file = ralph_root / "version.json"
    if version_file.exists():
        return json.loads(version_file.read_text())
    return {"version": "unknown", "releaseDate": "unknown", "templateCount": 0}


def get_source_commit(ralph_root: Path) -> str:
    """Get git commit hash from canonical Ralph root."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ralph_root,
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            return result.stdout.strip()[:12]
    except Exception:
        pass
    return "no-git"


def is_repo_dirty(path: Path) -> bool:
    """Check if git repo at path has uncommitted changes."""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=path,
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            return bool(result.stdout.strip())
    except Exception:
        pass
    return False


def create_meta(ralph_root: Path) -> dict:
    """Create metadata for .ralph-meta.json."""
    version_info = get_source_version(ralph_root)
    return {
        "sourceCommit": get_source_commit(ralph_root),
        "sourceRoot": str(ralph_root.resolve()),
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "templateVersion": version_info.get("version", "unknown"),
        "templateCount": version_info.get("templateCount", len(TEMPLATE_FILES)),
    }


def write_meta(target: Path, meta: dict) -> None:
    """Write .ralph-meta.json to target ralph directory."""
    meta_file = target / RALPH_META_FILE
    meta_file.write_text(json.dumps(meta, indent=2))


def read_meta(target: Path) -> Optional[dict]:
    """Read .ralph-meta.json from target ralph directory."""
    meta_file = target / RALPH_META_FILE
    if meta_file.exists():
        try:
            return json.loads(meta_file.read_text())
        except Exception:
            pass
    return None


# =============================================================================
# COMMANDS
# =============================================================================

def cmd_init(target_path: str) -> int:
    """Initialize Ralph in a project."""
    target = Path(target_path).resolve()
    ralph_dir = target / "ralph"

    if ralph_dir.exists():
        print(f"ERROR: Ralph already exists at {ralph_dir}")
        print("  Use --update to sync templates, or remove the directory first.")
        return 1

    ralph_root = find_ralph_root()
    if not ralph_root:
        print("ERROR: Cannot find canonical Ralph root.")
        print("")
        print("Set one of the following:")
        print("  1. Set RALPH_ROOT environment variable")
        print(f"  2. Create: {get_config_file()}")
        print("     (with the absolute path to canonical ralph repo)")
        print(f"  3. Ensure {DEFAULT_RALPH_ROOT} exists with valid structure")
        return 1

    print(f"Initializing Ralph in: {target}")
    print(f"  Source: {ralph_root}")

    # Create directory structure
    templates_dir = ralph_dir / "templates"
    runs_dir = ralph_dir / "runs"

    templates_dir.mkdir(parents=True, exist_ok=True)
    runs_dir.mkdir(parents=True, exist_ok=True)

    # Copy templates
    source_templates = ralph_root / "templates"
    copied = 0
    for filename in TEMPLATE_FILES:
        src = source_templates / filename
        dst = templates_dir / filename
        if src.exists():
            shutil.copy2(src, dst)
            copied += 1
        else:
            print(f"  Warning: template not found: {filename}")

    # Copy README files
    src_readme = ralph_root / "README.md"
    if src_readme.exists():
        shutil.copy2(src_readme, ralph_dir / "README.md")

    src_runs_readme = ralph_root / "runs" / "README.md"
    if src_runs_readme.exists():
        shutil.copy2(src_runs_readme, runs_dir / "README.md")

    # Write metadata
    meta = create_meta(ralph_root)
    write_meta(ralph_dir, meta)

    print("")
    print(f"Initialized Ralph successfully!")
    print(f"  Templates copied: {copied}")
    print(f"  Version: {meta['templateVersion']}")
    print(f"  Commit: {meta['sourceCommit']}")
    print("")
    print("Next steps:")
    print(f"  1. Read {ralph_dir / 'templates' / 'RUN_CHECKLIST.md'}")
    print(f"  2. Create a run: {runs_dir / 'YYYY-MM-DD__your-feature'}")

    return 0


def cmd_update(target_path: Optional[str], force: bool = False) -> int:
    """Update Ralph templates (preserves runs/)."""
    target = Path(target_path).resolve() if target_path else Path.cwd()
    ralph_dir = target / "ralph"

    if not ralph_dir.exists():
        print(f"ERROR: No Ralph directory found at {ralph_dir}")
        print("  Use --init to create one first.")
        return 1

    ralph_root = find_ralph_root()
    if not ralph_root:
        print("ERROR: Cannot find canonical Ralph root.")
        return 1

    # Check for dirty canonical repo
    if is_repo_dirty(ralph_root):
        if force:
            print(f"WARNING: Canonical repo has uncommitted changes (--force used)")
        else:
            print(f"ERROR: Canonical Ralph repo has uncommitted changes")
            print(f"  Path: {ralph_root}")
            print("")
            print("This prevents syncing half-edited template state.")
            print("Options:")
            print("  1. Commit or stash changes in the canonical repo")
            print("  2. Use --force to update anyway")
            return 1

    print(f"Updating Ralph in: {ralph_dir}")
    print(f"  Source: {ralph_root}")

    # Read existing meta for comparison
    old_meta = read_meta(ralph_dir)
    if old_meta:
        print(f"  Current version: {old_meta.get('templateVersion', 'unknown')}")

    # Update templates only (preserve runs/)
    templates_dir = ralph_dir / "templates"
    templates_dir.mkdir(parents=True, exist_ok=True)

    source_templates = ralph_root / "templates"
    updated = 0
    for filename in TEMPLATE_FILES:
        src = source_templates / filename
        dst = templates_dir / filename
        if src.exists():
            shutil.copy2(src, dst)
            updated += 1

    # Update README (but not runs/README which user may have customized)
    src_readme = ralph_root / "README.md"
    if src_readme.exists():
        shutil.copy2(src_readme, ralph_dir / "README.md")

    # Write new metadata
    meta = create_meta(ralph_root)
    write_meta(ralph_dir, meta)

    print("")
    print(f"Updated Ralph successfully!")
    print(f"  Templates updated: {updated}")
    print(f"  New version: {meta['templateVersion']}")
    print(f"  Commit: {meta['sourceCommit']}")
    print(f"  runs/ directory: preserved")

    return 0


def cmd_doctor(target_path: Optional[str]) -> int:
    """Validate Ralph setup."""
    target = Path(target_path).resolve() if target_path else Path.cwd()
    ralph_dir = target / "ralph"

    print(f"Checking Ralph health in: {target}")
    print("")

    issues = []
    warnings = []

    # Check if ralph directory exists
    if not ralph_dir.exists():
        issues.append(f"No ralph/ directory found at {ralph_dir}")
        print("RESULT: FAIL")
        print("")
        for issue in issues:
            print(f"  ERROR: {issue}")
        print("")
        print("Run: /ralph-services --init <path>")
        return 1

    # Check templates directory
    templates_dir = ralph_dir / "templates"
    if not templates_dir.exists():
        issues.append("Missing templates/ directory")
    else:
        # Check for required templates
        required = [
            "HOW_RALPH_WORKS.md",
            "PROMPT_TEMPLATE.md",
            "PRD_TEMPLATE.md",
            "PRD_JSON_TEMPLATE.json",
        ]
        for filename in required:
            if not (templates_dir / filename).exists():
                issues.append(f"Missing required template: {filename}")

        # Check for other templates
        missing = []
        for filename in TEMPLATE_FILES:
            if not (templates_dir / filename).exists():
                missing.append(filename)
        if missing and len(missing) < len(TEMPLATE_FILES):
            warnings.append(f"Missing {len(missing)} optional templates")

    # Check runs directory
    runs_dir = ralph_dir / "runs"
    if not runs_dir.exists():
        warnings.append("Missing runs/ directory")

    # Check metadata
    meta = read_meta(ralph_dir)
    if not meta:
        warnings.append("Missing .ralph-meta.json (version tracking)")
    else:
        print(f"  Version: {meta.get('templateVersion', 'unknown')}")
        print(f"  Commit: {meta.get('sourceCommit', 'unknown')}")
        print(f"  Installed: {meta.get('timestamp', 'unknown')}")
        print("")

    # Check canonical source
    ralph_root = find_ralph_root()
    if ralph_root:
        print(f"  Canonical source: {ralph_root}")
        source_version = get_source_version(ralph_root)
        canonical_ver = source_version.get("version", "unknown")
        print(f"  Canonical version: {canonical_ver}")

        if meta:
            project_ver = meta.get("templateVersion", "unknown")
            if project_ver != canonical_ver:
                warnings.append(
                    f"Version mismatch: project={project_ver}, canonical={canonical_ver}"
                )
                warnings.append("  Run: /ralph-services --update to sync templates")
    else:
        warnings.append("Canonical Ralph root not found (updates unavailable)")

    print("")

    # Report results
    if issues:
        print("RESULT: FAIL")
        print("")
        for issue in issues:
            print(f"  ERROR: {issue}")
    elif warnings:
        print("RESULT: OK (with warnings)")
        print("")
        for warning in warnings:
            print(f"  WARN: {warning}")
    else:
        print("RESULT: HEALTHY")

    return 1 if issues else 0


def cmd_set_root(path: str) -> int:
    """Save canonical Ralph root to user config."""
    root = Path(path).resolve()

    if not root.exists():
        print(f"ERROR: Path does not exist: {root}")
        return 1

    if not is_valid_ralph_root(root):
        print(f"ERROR: Path is not a valid Ralph root: {root}")
        print("  Expected: templates/ directory and version.json")
        return 1

    save_ralph_root(root)
    print(f"Set Ralph root to: {root}")
    return 0


def cmd_print_root() -> int:
    """Print resolved canonical Ralph root and its source."""
    path, source = find_ralph_root_with_source()

    source_labels = {
        "env": f"RALPH_ROOT environment variable",
        "config": f"config file ({get_config_file()})",
        "fallback": f"fallback default ({DEFAULT_RALPH_ROOT})",
        "none": "not found",
    }

    if path:
        version_info = get_source_version(path)
        commit = get_source_commit(path)
        dirty = is_repo_dirty(path)

        print(f"Canonical Ralph root: {path}")
        print(f"  Source: {source_labels[source]}")
        print(f"  Version: {version_info.get('version', 'unknown')}")
        print(f"  Commit: {commit}")
        if dirty:
            print(f"  Status: DIRTY (uncommitted changes)")
        else:
            print(f"  Status: clean")
        return 0
    else:
        print("ERROR: Canonical Ralph root not found")
        print("")
        print("Checked (in order):")
        print(f"  1. RALPH_ROOT env var: {os.environ.get('RALPH_ROOT', '(not set)')}")
        print(f"  2. Config file: {get_config_file()}")
        print(f"  3. Fallback: {DEFAULT_RALPH_ROOT}")
        return 1


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="ralph-services: Bootstrap, validate, and update Ralph workflow infrastructure"
    )
    parser.add_argument(
        "--init",
        metavar="PATH",
        help="Initialize Ralph in a project at PATH",
    )
    parser.add_argument(
        "--update",
        nargs="?",
        const=".",
        metavar="PATH",
        help="Update Ralph templates (preserves runs/). Defaults to current directory.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force update even if canonical repo has uncommitted changes",
    )
    parser.add_argument(
        "--doctor",
        nargs="?",
        const=".",
        metavar="PATH",
        help="Validate Ralph setup. Defaults to current directory.",
    )
    parser.add_argument(
        "--set-root",
        metavar="PATH",
        help="Save canonical Ralph root to user config",
    )
    parser.add_argument(
        "--print-root",
        action="store_true",
        help="Print resolved canonical Ralph root and its source",
    )

    args = parser.parse_args()

    # Dispatch to command
    if args.print_root:
        return cmd_print_root()
    elif args.init:
        return cmd_init(args.init)
    elif args.update is not None:
        return cmd_update(args.update if args.update != "." else None, force=args.force)
    elif args.doctor is not None:
        return cmd_doctor(args.doctor if args.doctor != "." else None)
    elif args.set_root:
        return cmd_set_root(args.set_root)
    else:
        parser.print_help()
        return 0


if __name__ == "__main__":
    sys.exit(main())
