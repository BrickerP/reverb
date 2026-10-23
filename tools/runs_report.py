#!/usr/bin/env python3
"""Summarize Take Stack runs.jsonl files into a Markdown report.

Usage:
    python3 tools/runs_report.py path/to/runs.jsonl [more.jsonl ...]
    python3 tools/runs_report.py runs.jsonl --out report.md
"""
import argparse
import json
import statistics
import sys
from collections import Counter, defaultdict

NAMES = {"looper": "Looper", "solo": "Soloist", "mirror": "Mirror"}


def load(paths):
    runs = []
    skipped = 0
    for path in paths:
        try:
            f = open(path, "r", encoding="utf-8")
        except OSError as exc:
            print(f"skip {path}: {exc}", file=sys.stderr)
            continue
        with f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    skipped += 1
                    continue
                if isinstance(data, dict):
                    runs.append(data)
                else:
                    skipped += 1
    return runs, skipped


def norm(run):
    run["won"] = bool(run.get("won", False))
    run["wave"] = int(run.get("wave", 0))
    run["kills"] = int(run.get("kills", 0))
    run["seconds"] = float(run.get("seconds", 0.0))
    run["character"] = str(run.get("character", "?"))
    weapons = run.get("weapons", [])
    run["weapons"] = [str(w) for w in weapons] if isinstance(weapons, list) else []
    return run


def pct(part, total):
    return 100.0 * part / total if total else 0.0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", help="runs.jsonl files")
    parser.add_argument("--out", help="write Markdown to this file instead of stdout")
    args = parser.parse_args()

    runs, skipped = load(args.paths)
    runs = [norm(r) for r in runs]
    if not runs:
        print("No valid runs.", file=sys.stderr)
        return 1

    lines = ["# Take Stack run report", ""]
    wins = sum(1 for r in runs if r["won"])
    lines.append(f"Runs: **{len(runs)}** · wins **{wins}** · win rate **{pct(wins, len(runs)):.1f}%**")
    versions = Counter(str(r.get("version") or "?") for r in runs)
    lines.append("Versions: " + " · ".join(f"{v}: {n}" for v, n in versions.most_common()))
    lines.append("")

    by_char = defaultdict(list)
    for run in runs:
        by_char[run["character"]].append(run)
    lines.append("## By character")
    lines.append("")
    lines.append("| Character | Runs | Wins | Win rate | Mean wave | Median wave | Mean kills |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|")
    for char in sorted(by_char):
        group = by_char[char]
        char_wins = sum(1 for r in group if r["won"])
        waves = [r["wave"] for r in group]
        kills = [r["kills"] for r in group]
        lines.append(
            f"| {NAMES.get(char, char)} | {len(group)} | {char_wins} | "
            f"{pct(char_wins, len(group)):.1f}% | {statistics.mean(waves):.1f} | "
            f"{statistics.median(waves):g} | {statistics.mean(kills):.0f} |"
        )
    lines.append("")

    losses = [r for r in runs if not r["won"]]
    if losses:
        deaths = Counter(r["wave"] for r in losses)
        lines.append("## Death waves")
        lines.append("")
        lines.append(" · ".join(f"{wave}: {deaths[wave]}" for wave in sorted(deaths)))
        lines.append("")

    weapon_stats = defaultdict(lambda: [0, 0])
    for run in runs:
        for weapon in set(run["weapons"]):
            weapon_stats[weapon][0] += 1
            if run["won"]:
                weapon_stats[weapon][1] += 1
    rows = [(w, n, wins, pct(wins, n)) for w, (n, wins) in weapon_stats.items() if n >= 3]
    if rows:
        rows.sort(key=lambda row: (-row[3], -row[1]))
        lines.append("## Weapons (runs with at least 3 appearances)")
        lines.append("")
        lines.append("| Weapon | Runs | Wins | Win rate |")
        lines.append("|---|---:|---:|---:|")
        for weapon, n, wins, rate in rows:
            lines.append(f"| {weapon} | {n} | {wins} | {rate:.1f}% |")
        lines.append("")

    lines.append("## Recent runs")
    lines.append("")
    lines.append("| Seed | Character | Result | Wave | Kills | Time |")
    lines.append("|---:|---|---|---:|---:|---:|")
    for run in runs[-10:][::-1]:
        result = "WIN" if run["won"] else "loss"
        lines.append(
            f"| {run.get('seed', '?')} | {NAMES.get(run['character'], run['character'])} | "
            f"{result} | {run['wave']} | {run['kills']} | {run['seconds']:.0f}s |"
        )
    lines.append("")

    if skipped:
        lines.append(f"Skipped {skipped} malformed line(s).")

    text = "\n".join(lines)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
        print(f"wrote {args.out}")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
