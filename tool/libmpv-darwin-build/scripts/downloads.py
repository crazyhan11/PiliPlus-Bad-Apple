#!/usr/bin/env python3

import hashlib
import pathlib
import subprocess
import sys
import time
import urllib.parse
import urllib.request


def parse_lock(path):
    dependencies = {}
    current = None
    for raw_line in pathlib.Path(path).read_text(encoding="utf-8").splitlines():
        if raw_line and not raw_line.startswith(" ") and raw_line.endswith(":"):
            current = raw_line[:-1]
            dependencies[current] = {}
        elif current and raw_line.startswith("  ") and ":" in raw_line:
            key, value = raw_line.strip().split(":", 1)
            dependencies[current][key] = value.strip().strip('"')
    return dependencies


def archive_extension(url):
    suffixes = pathlib.PurePosixPath(urllib.parse.urlparse(url).path).suffixes
    return "".join(suffixes[-2:])


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    lock_path, destination = sys.argv[1:3]
    destination = pathlib.Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for name, dependency in parse_lock(lock_path).items():
        extension = archive_extension(dependency["url"])
        output = destination / f'{name}-{dependency["version"]}{extension}'
        temporary = destination / f'.{output.name}.tmp'
        print(output, flush=True)
        if output.exists() and sha256(output) == dependency["sha256"]:
            continue
        for attempt in range(1, 6):
            try:
                subprocess.run(
                    [
                        "curl", "--fail", "--location", "--http1.1",
                        "--retry", "3", "--retry-all-errors", "--continue-at", "-",
                        dependency["url"], "--output", str(temporary),
                    ],
                    check=True,
                )
                if sha256(temporary) != dependency["sha256"]:
                    raise RuntimeError(f"checksum mismatch: {output}")
                temporary.replace(output)
                break
            except Exception:
                temporary.unlink(missing_ok=True)
                if attempt == 5:
                    raise
                time.sleep(attempt * 2)


if __name__ == "__main__":
    main()
