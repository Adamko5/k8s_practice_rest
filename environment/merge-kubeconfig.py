#!/usr/bin/env python3
"""Merge this lab's generated admin config into the current user's kubeconfig."""

import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile


def read_config(path, *, minify=False):
    command = ["kubectl", "--kubeconfig", str(path), "config", "view", "--raw", "--flatten", "-o", "json"]
    if minify:
        command.append("--minify")
    return json.loads(subprocess.check_output(command, text=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Generated admin.conf copied from bank-lab-cp1")
    parser.add_argument("--backup-dir", type=Path, help="Backup location; defaults to the source file's directory")
    args = parser.parse_args()
    source = args.source.resolve(strict=True)
    destination = Path.home() / ".kube/config"
    if destination.is_symlink():
        raise SystemExit("Existing ~/.kube/config is a symlink; inspect its target before replacing it.")

    lab = read_config(source, minify=True)
    if any(len(lab.get(section, [])) != 1 for section in ("clusters", "users", "contexts")):
        raise SystemExit("Expected one cluster, user, and context in the source admin config.")
    cluster = lab["clusters"][0]["cluster"]
    if cluster.get("server") != "https://192.168.77.10:6443" or cluster.get("insecure-skip-tls-verify"):
        raise SystemExit("Source must target the lab API endpoint with TLS verification enabled.")
    lab["clusters"][0]["name"] = "bank-lab"
    lab["users"][0]["name"] = "bank-lab-admin"
    lab["contexts"] = [{"name": "bank-lab", "context": {
        "cluster": "bank-lab", "user": "bank-lab-admin", "namespace": "default"}}]
    lab["current-context"] = "bank-lab"

    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    previous_bytes = destination.read_bytes() if destination.exists() else None
    previous = read_config(destination) if previous_bytes is not None else {}
    with tempfile.TemporaryDirectory(prefix=".bank-lab-", dir=destination.parent) as temporary:
        incoming = Path(temporary) / "incoming"
        incoming.write_text(json.dumps(lab))
        incoming.chmod(0o600)
        canonical = read_config(incoming)
        for section in ("clusters", "users", "contexts"):
            names = {row["name"]: row for row in canonical[section]}
            for old in previous.get(section, []):
                if old["name"] in names and old != names[old["name"]]:
                    raise SystemExit(f"Existing {section} entry {old['name']} differs; inspect it before replacing lab access.")
        environment = os.environ.copy()
        environment["KUBECONFIG"] = str(incoming) + (os.pathsep + str(destination) if previous_bytes is not None else "")
        merged = subprocess.check_output(
            ["kubectl", "config", "view", "--raw", "--flatten", "--merge", "-o", "json"],
            env=environment,
        )
        result = json.loads(merged)
        for section in ("clusters", "users", "contexts"):
            by_name = {row["name"]: row for row in result.get(section, [])}
            for old in previous.get(section, []):
                if by_name.get(old["name"]) != old:
                    raise SystemExit(f"Merge would change existing {section} entry {old['name']}.")
        if result == previous:
            print(f"Context bank-lab is already selected in {destination}.")
            return
        if previous_bytes is not None:
            backup_dir = (args.backup_dir or source.parent).resolve()
            backup_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
            stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
            backup = backup_dir / f"kubeconfig-before-bank-lab-{stamp}"
            with os.fdopen(os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as handle:
                handle.write(previous_bytes)
            print(f"Previous config backed up at {backup}")
        staged = Path(temporary) / "config"
        staged.write_bytes(merged)
        staged.chmod(0o600)
        os.replace(staged, destination)
    print(f"Selected context bank-lab in {destination} (local lab administrator).")


if __name__ == "__main__":
    main()
