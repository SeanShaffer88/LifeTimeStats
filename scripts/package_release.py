"""Build a reproducible, version-checked GitHub release archive."""
from __future__ import annotations

import argparse
import hashlib
import re
import tempfile
from pathlib import Path, PurePosixPath
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

METADATA = {
    ".pkgmeta", "AUDIT.md", "CHANGELOG.md", "CREDITS.md", "DESCRIPTION.md",
    "LICENSE", "README.md", "icon.png", "logo.png",
}
SKIP_DIRS = {".git", "__pycache__", "dist", "docs", "scripts", "tests"}
TOC = "LifeTimeStats.toc"


def version_from_toc(root: Path) -> str:
    toc = (root / TOC).read_text(encoding="utf-8")
    match = re.search(r"(?m)^## Version:\s*(\d+\.\d+\.\d+)\s*$", toc)
    if not match:
        raise ValueError("The addon TOC needs a semantic ## Version field.")
    return match.group(1)


def files_for_archive(root: Path) -> list[Path]:
    if not (root / "LICENSE").is_file() or not (root / TOC).is_file():
        raise ValueError("The release source must contain the addon manifest and license.")
    files: list[Path] = []
    for path in root.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(root)
        if set(relative.parts) & SKIP_DIRS:
            continue
        if len(relative.parts) == 1:
            if path.name == TOC or path.name in METADATA or path.suffix.lower() == ".lua":
                files.append(path)
        elif relative.parts[0] == "Media":
            files.append(path)

    selected = {p.relative_to(root).as_posix() for p in files}
    toc_files = re.findall(r"(?m)^\s*([A-Za-z0-9_./\\-]+\.lua)\s*$",
                           (root / TOC).read_text(encoding="utf-8"))
    missing = [name for name in toc_files
               if PurePosixPath(name.replace("\\", "/")).as_posix() not in selected]
    if missing:
        raise ValueError("TOC references files missing from the package: " + ", ".join(missing))
    required_media = {"Media/icon.tga", "Media/dot.tga"}
    missing_media = sorted(required_media - selected)
    if missing_media:
        raise ValueError("The release archive is missing required Media assets: " + ", ".join(missing_media))
    return sorted(files, key=lambda p: p.relative_to(root).as_posix())


def notes_from_changelog(root: Path, version: str) -> str:
    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    heading = f"## [{version}-forever]"
    if heading not in changelog:
        raise ValueError(f"CHANGELOG.md has no {heading} release notes.")
    section = changelog.split(heading, 1)[1].split("\n## [", 1)[0].strip()
    return f"# LifeTimeStats {version}-forever\n\n{section}\n"


def build(root: Path, output: Path, tag: str) -> tuple[Path, Path, Path]:
    root = root.resolve()
    output = output.resolve()
    try:
        output.relative_to(root)
    except ValueError:
        pass
    else:
        raise ValueError("Build artifacts must be written outside the addon source directory.")

    version = version_from_toc(root)
    expected_tag = f"v{version}-forever"
    if tag != expected_tag:
        raise ValueError(f"Release tag {tag!r} must match the TOC version ({expected_tag}).")
    files = files_for_archive(root)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"LifeTimeStats-{version}-forever.zip"
    notes = output / "release-notes.md"
    with ZipFile(archive, "w", compression=ZIP_DEFLATED, compresslevel=9) as zf:
        for source in files:
            relative = source.relative_to(root).as_posix()
            info = ZipInfo(f"LifeTimeStats/{relative}", date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            zf.writestr(info, source.read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)

    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    checksum = output / f"{archive.name}.sha256"
    checksum.write_text(f"{digest}  {archive.name}\n", encoding="ascii")
    notes.write_text(notes_from_changelog(root, version), encoding="utf-8")
    return archive, checksum, notes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True, help="Git tag, e.g. v1.13.0-forever")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    output = args.output or (Path(tempfile.gettempdir()) / "LifeTimeStats-release")
    archive, checksum, notes = build(args.root, output, args.tag)
    print(f"Package: {archive}")
    print(f"SHA-256: {checksum}")
    print(f"Release notes: {notes}")


if __name__ == "__main__":
    main()
