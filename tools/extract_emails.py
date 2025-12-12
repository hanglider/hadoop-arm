#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path

PROGRESS_EVERY = 50000  # печатать прогресс каждые N строк

def run_ok(cmd, cwd=None):
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{p.stderr}")
    return p.stdout

def repo_dir_name(url: str) -> str:
    name = url.rstrip("/").split("/")[-1]
    if name.endswith(".git"):
        name = name[:-4]
    return name or "repo"

def ensure_repo(url: str, cache_dir: Path) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    d = cache_dir / repo_dir_name(url)
    if d.exists() and (d / ".git").exists():
        print(f"[git] fetch {url}", file=sys.stderr)
        run_ok(["git", "fetch", "--all", "--prune"], cwd=str(d))
    else:
        if d.exists():
            # снести мусорную папку
            for p in sorted(d.rglob("*"), reverse=True):
                try:
                    p.unlink() if p.is_file() else p.rmdir()
                except Exception:
                    pass
            try:
                d.rmdir()
            except Exception:
                pass
        print(f"[git] clone {url}", file=sys.stderr)
        # --progress пишет в stderr, это нормально (видно как прогресс клона)
        p = subprocess.run(["git", "clone", "--progress", url, str(d)])
        if p.returncode != 0:
            raise RuntimeError(f"git clone failed: {url}")
    return d

def stream_emails(repo_path: Path, max_commits: int | None):
    cmd = ["git", "-C", str(repo_path), "log", "--no-merges", "--pretty=format:%ae"]
    if max_commits is not None and max_commits > 0:
        cmd.insert(-1, str(max_commits))
        cmd.insert(-1, "-n")

    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert p.stdout is not None
    assert p.stderr is not None

    count = 0
    for line in p.stdout:
        s = line.strip()
        if not s:
            continue
        count += 1
        yield s
        if count % PROGRESS_EVERY == 0:
            print(f"[log] {repo_path.name}: processed {count} emails...", file=sys.stderr)

    stderr_tail = p.stderr.read()
    rc = p.wait()
    if rc != 0:
        raise RuntimeError(f"git log failed in {repo_path}\n{stderr_tail}")

    print(f"[log] {repo_path.name}: done, {count} emails", file=sys.stderr)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repos", required=True, help="repos.txt (one URL per line)")
    ap.add_argument("--out", required=True, help="output file (one email per line)")
    ap.add_argument("--cache-dir", default="data/repos_cache")
    ap.add_argument("--max-commits", type=int, default=0, help="0 = no limit")
    args = ap.parse_args()

    repos_file = Path(args.repos)
    out_file = Path(args.out)
    cache_dir = Path(args.cache_dir)

    urls = []
    for raw in repos_file.read_text(encoding="utf-8").splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        urls.append(s)

    max_commits = args.max_commits if args.max_commits and args.max_commits > 0 else None

    out_file.parent.mkdir(parents=True, exist_ok=True)

    total = 0
    with out_file.open("w", encoding="utf-8") as f:
        for url in urls:
            repo_path = ensure_repo(url, cache_dir)
            for email in stream_emails(repo_path, max_commits=max_commits):
                f.write(email + "\n")
                total += 1

    print(f"OK: wrote {total} emails to {out_file}", file=sys.stderr)

if __name__ == "__main__":
    main()