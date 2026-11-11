"""Unit tests for version, manifest, path safety, reproducibility and SHA generation."""
import hashlib
import importlib.util
import tempfile
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "package_release.py"
SPEC = importlib.util.spec_from_file_location("package_release", SCRIPT)
package = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(package)


def expect_error(fn, text):
    try:
        fn()
    except ValueError as exc:
        assert text in str(exc), str(exc)
    else:
        raise AssertionError(f"expected package error: {text}")


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary) / "source"
    root.mkdir()
    (root / "Core.lua").write_text("return true\n", encoding="utf-8")
    (root / "Expanded.lua").write_text("return false\n", encoding="utf-8")
    (root / "LICENSE").write_text("GPL-3.0-or-later\n", encoding="utf-8")
    (root / "README.md").write_text("release fixture\n", encoding="utf-8")
    (root / "CHANGELOG.md").write_text(
        "## [1.13.0-forever] - 2026-11-11\n\n### Added\n- fixture\n\n## [1.12.2-forever]\n",
        encoding="utf-8",
    )
    (root / ".pkgmeta").write_text("package-as: LifeTimeStats\n", encoding="utf-8")
    (root / ".gitignore").write_text("ignored\n", encoding="utf-8")
    media = root / "Media"
    (media / "icons").mkdir(parents=True)
    (media / "icon.tga").write_bytes(b"fixture-icon")
    (media / "dot.tga").write_bytes(b"fixture-dot")
    (media / "icons" / "corpse.tga").write_bytes(b"fixture-corpse")
    (root / "tests").mkdir()
    (root / "tests" / "private_fixture.txt").write_text("must not ship", encoding="utf-8")
    (root / "docs").mkdir()
    (root / "docs" / "screenshot.png").write_bytes(b"not a runtime asset")
    (root / "scripts").mkdir()
    (root / "scripts" / "package_release.py").write_text("dev-only", encoding="utf-8")
    (root / "LifeTimeStats.toc").write_text(
        "## Interface: 16001\n## Version: 1.13.0\n\nCore.lua\nExpanded.lua\nMedia/icon.tga\n",
        encoding="utf-8",
    )

    dist = Path(temporary) / "dist"
    archive, checksum, notes = package.build(root, dist, "v1.13.0-forever")
    with zipfile.ZipFile(archive) as zf:
        assert zf.testzip() is None
        names = set(zf.namelist())
        assert "LifeTimeStats/LifeTimeStats.toc" in names
        assert "LifeTimeStats/Media/icons/corpse.tga" in names
        assert "LifeTimeStats/LICENSE" in names
        assert not any("/tests/" in n or "/docs/" in n or "/scripts/" in n for n in names)
        assert "LifeTimeStats/.gitignore" not in names
        assert zf.read("LifeTimeStats/README.md") == b"release fixture\n"
    assert checksum.read_text(encoding="ascii").split()[0] == hashlib.sha256(archive.read_bytes()).hexdigest()
    assert "fixture" in notes.read_text(encoding="utf-8")
    archive_copy, _, _ = package.build(root, Path(temporary) / "second-dist", "v1.13.0-forever")
    assert archive.read_bytes() == archive_copy.read_bytes(), "identical inputs should yield identical ZIPs"
    expect_error(lambda: package.build(root, dist, "v1.14.0-forever"), "must match the TOC")

    (root / "Media" / "dot.tga").unlink()
    expect_error(lambda: package.build(root, dist, "v1.13.0-forever"), "required Media assets")
    (root / "Media" / "dot.tga").write_bytes(b"fixture-dot")

    (root / "LifeTimeStats.toc").write_text(
        "## Version: 1.13.0\nCore.lua\nMissing.lua\n", encoding="utf-8"
    )
    expect_error(lambda: package.build(root, dist, "v1.13.0-forever"), "files missing from the package")

print("PACKAGE PASS: deterministic archive, manifest coverage, exclusions and SHA-256 verified")
