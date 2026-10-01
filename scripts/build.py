"""Build from the arranged local language/export source; never fetch or copy originals."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = ROOT / "language/export"
    if not (source / "README.md").is_file():
        raise SystemExit("Missing pages/language/export/README.md. Arrange the local language link or checkout before building; no remote source fetch is performed.")
    output = ROOT / "build"
    if output.is_symlink():
        raise SystemExit("Refusing to write through a symbolic link at build/.")
    subprocess.run([sys.executable, "-m", "mkdocs", "build", "--strict",
                    "--config-file", str(ROOT / "site/mkdocs.yml"),
                    "--site-dir", str(output)], cwd=ROOT, check=True)
    subprocess.run([sys.executable, str(ROOT / ".github/scripts/check_site_publication.py"),
                    "--site-dir", str(output), "--check-repositories"], cwd=ROOT, check=True)
    print("Verified static website is ready in build/. Review and commit it for deployment.")


if __name__ == "__main__":
    main()
