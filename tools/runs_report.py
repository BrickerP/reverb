#!/usr/bin/env python3
"""Summarize Take Stack run and feedback JSONL files as Markdown."""
import argparse
import json
import math
import re
import statistics
import sys
from collections import Counter, defaultdict

NAMES = {"looper": "Looper", "solo": "Soloist", "mirror": "Mirror", "conductor": "Conductor"}
SOURCES = ("manual", "fixture", "bot", "unknown")
FEEDBACK_CATEGORIES = ("builds", "shop", "combat", "echoes", "performance", "other")
FEEDBACK_RATINGS = ("good", "mixed", "frustrating")
RUN_ID_RE = re.compile(r"^[A-Za-z0-9_.:-]{8,128}$")


def load(paths):
    records, skipped = [], 0
    for path in paths:
        try:
            stream = open(path, "rb")
        except OSError as exc:
            print(f"skip {path}: {exc}", file=sys.stderr)
            skipped += 1
            continue
        with stream:
            for raw_line in stream:
                try:
                    line = raw_line.decode("utf-8").strip()
                except UnicodeDecodeError:
                    skipped += 1
                    continue
                if not line:
                    continue
                try:
                    data = json.loads(line)
                except (json.JSONDecodeError, UnicodeError):
                    skipped += 1
                    continue
                if isinstance(data, dict):
                    records.append(data)
                else:
                    skipped += 1
    return records, skipped


def _integer(value, minimum=0):
    if isinstance(value, bool):
        raise ValueError
    if isinstance(value, int):
        result = value
    elif isinstance(value, float):
        if not math.isfinite(value) or not value.is_integer():
            raise ValueError
        result = int(value)
    elif isinstance(value, str) and value.strip():
        number = float(value.strip())
        if not math.isfinite(number) or not number.is_integer():
            raise ValueError
        result = int(number)
    else:
        raise ValueError
    if result < minimum:
        raise ValueError
    return result


def _number(value, minimum=0.0):
    if isinstance(value, bool):
        raise ValueError
    result = float(value)
    if not math.isfinite(result) or result < minimum:
        raise ValueError
    return result


def _boolean(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if math.isfinite(float(value)) and value in (0, 1):
            return bool(value)
    if isinstance(value, str):
        text = value.strip().lower()
        if text in ("true", "1"):
            return True
        if text in ("false", "0"):
            return False
    raise ValueError


def _text(value, allow_empty=False):
    if not isinstance(value, str):
        raise ValueError
    result = value.strip()
    if not result and not allow_empty:
        raise ValueError
    return result


def _source(value):
    return value if isinstance(value, str) and value in SOURCES else "unknown"


def _provenance_source(value):
    value = _text(value)
    if value not in SOURCES:
        raise ValueError
    return value


def _run_id(value):
    value = _text(value)
    if RUN_ID_RE.fullmatch(value) is None:
        raise ValueError
    return value


def norm(run):
    """Return a normalized run, or None when its metric fields are invalid."""
    try:
        result = dict(run)
        result["won"] = _boolean(run.get("won", False))
        result["endless"] = _boolean(run.get("endless", False))
        result["boss_rush"] = _boolean(run.get("boss_rush", False))
        result["daily_modifier"] = _text(run.get("daily_modifier", ""), allow_empty=True)
        result["ascension"] = _integer(run.get("ascension", 0))
        boons = run.get("boons", [])
        if not isinstance(boons, list) or any(not isinstance(item, str) for item in boons):
            raise ValueError
        result["boons"] = list(boons)
        result["echo_refreshes"] = _integer(run.get("echo_refreshes", 0))
        for key in ("contracts_accepted", "contracts_completed", "contracts_failed"):
            result[key] = _integer(run.get(key, 0))
        result["wave"] = _integer(run.get("wave", 0))
        result["kills"] = _integer(run.get("kills", 0))
        result["seconds"] = _number(run.get("seconds", 0.0))
        result["character"] = _text(run.get("character", "?"))
        weapons = run.get("weapons", [])
        if not isinstance(weapons, list) or any(not isinstance(item, str) for item in weapons):
            raise ValueError
        result["weapons"] = list(weapons)
        build = run.get("build_commit")
        run_id = run.get("run_id")
        result["run_id"] = _run_id(run_id) if run_id is not None else ""
        schema = _integer(run["schema_version"], 1) if "schema_version" in run else 1
        if schema >= 2:
            if not result["run_id"]:
                raise ValueError
            _text(run.get("recorded_at_utc"))
            result["source"] = _provenance_source(run.get("source"))
            result["build_commit"] = _text(build)
            result["seed"] = _integer(run.get("seed"))
            result["version"] = _text(run.get("version"))
        else:
            # Rows predating schema 2 have no trustworthy provenance, even if
            # ad-hoc fields with these names were added by hand.
            result["source"] = "unknown"
            result["build_commit"] = "unavailable"
            if "seed" in run:
                result["seed"] = _integer(run["seed"])
        return result
    except (TypeError, ValueError, OverflowError):
        return None


def norm_feedback(record):
    try:
        if _integer(record.get("schema_version"), 1) != 1:
            raise ValueError
        run_id = _run_id(record.get("run_id"))
        category = _text(record.get("category"))
        rating = _text(record.get("rating"))
        note = _text(record.get("note", ""), allow_empty=True)
        if category not in FEEDBACK_CATEGORIES or rating not in FEEDBACK_RATINGS or len(note) > 500:
            raise ValueError
        result = dict(record)
        result.update(
            run_id=run_id,
            category=category,
            rating=rating,
            note=note,
            source=_provenance_source(record.get("source")),
            build_commit=_text(record.get("build_commit")),
            version=_text(record.get("version")),
            character=_text(record.get("character")),
            wave=_integer(record.get("wave")),
            won=_boolean(record.get("won")),
            seed=_integer(record.get("seed")),
        )
        _text(record.get("submitted_at_utc"))
        return result
    except (TypeError, ValueError, OverflowError):
        return None


def _mode(run):
    if run["boss_rush"]:
        return "Boss Rush"
    if run["endless"]:
        return "Endless"
    if run["daily_modifier"]:
        return "Daily"
    return "Normal"


def pct(part, total):
    return 100.0 * part / total if total else 0.0


def markdown(value):
    return str(value).replace("\\", "\\\\").replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def _provenance_matches(run, feedback):
    # Missing fields are tolerated for compatibility; contradictory snapshots
    # are never displayed as attributable feedback.
    for key in ("source", "build_commit", "version", "seed", "character", "wave", "won"):
        if key not in feedback or key not in run:
            continue
        left, right = feedback[key], run[key]
        if key == "source":
            left, right = _source(left), run["source"]
        elif key == "wave":
            try:
                left = _integer(left)
            except (TypeError, ValueError, OverflowError):
                return False
        elif key == "won":
            try:
                left = _boolean(left)
            except (TypeError, ValueError, OverflowError):
                return False
        if left != right:
            return False
    return True


def join_feedback(runs, feedback):
    runs_by_id = defaultdict(list)
    for run in runs:
        if run["run_id"]:
            runs_by_id[run["run_id"]].append(run)
    by_id = {run_id: entries[0] for run_id, entries in runs_by_id.items() if len(entries) == 1}
    grouped = defaultdict(list)
    for item in feedback:
        grouped[item["run_id"]].append(item)
    joined, warnings = [], Counter()
    warnings["duplicate_run"] = sum(len(entries) for entries in runs_by_id.values() if len(entries) > 1)
    for run_id, entries in grouped.items():
        if run_id in runs_by_id and len(runs_by_id[run_id]) > 1:
            continue
        if run_id not in by_id:
            warnings["orphan"] += len(entries)
        elif len(entries) != 1:
            warnings["duplicate"] += len(entries)
        elif not _provenance_matches(by_id[run_id], entries[0]):
            warnings["mismatch"] += 1
        else:
            joined.append((by_id[run_id], entries[0]))
    return joined, warnings


def build_report(runs, skipped_runs=0, feedback=(), skipped_feedback=0, source_filter=None):
    excluded_ids = set()
    if source_filter:
        excluded_ids = {run["run_id"] for run in runs if run["run_id"] and run["source"] not in source_filter}
        runs = [run for run in runs if run["source"] in source_filter]
        feedback = [item for item in feedback if item["run_id"] not in excluded_ids]
    if not runs:
        return None
    lines = ["# Take Stack run report", ""]
    wins = sum(run["won"] for run in runs)
    lines.append(f"Runs: **{len(runs)}** · wins **{wins}** · win rate **{pct(wins, len(runs)):.1f}%**")
    if source_filter:
        lines.append("Source filter: " + ", ".join(sorted(source_filter)))
    versions = Counter(str(run.get("version") or "?") for run in runs)
    sources = Counter(run["source"] for run in runs)
    builds = Counter(run["build_commit"] for run in runs)
    lines.append("Versions: " + " · ".join(f"{markdown(value)}: {count}" for value, count in versions.most_common()))
    lines.append("Sources: " + " · ".join(f"{source}: {sources[source]}" for source in SOURCES if sources[source]))
    lines.append("Builds: " + " · ".join(f"{markdown(build)}: {count}" for build, count in builds.most_common()))
    causes = Counter(str(run.get("death_cause") or "?") for run in runs if not run["won"])
    if causes:
        lines.append("Deaths: " + " · ".join(f"{markdown(cause)}: {count}" for cause, count in causes.most_common()))
    lines.append("")

    modes = Counter()
    for run in runs:
        if run["boss_rush"]:
            modes["Boss Rush"] += 1
        elif run["endless"]:
            modes["Endless"] += 1
        elif run["daily_modifier"]:
            modes["Daily"] += 1
        else:
            modes["Normal"] += 1
    lines += ["## Modes", "", "| Mode | Runs | Wins | Mean wave |", "|---|---:|---:|---:|"]
    for mode in ("Normal", "Daily", "Endless", "Boss Rush"):
        count = modes[mode]
        if not count:
            continue
        group = [run for run in runs if _mode(run) == mode]
        mode_wins = sum(run["won"] for run in group)
        lines.append(f"| {mode} | {count} | {mode_wins} | {statistics.mean([run['wave'] for run in group]):.1f} |")
    lines.append("")
    daily_runs = [run for run in runs if run["daily_modifier"]]
    anomalies = Counter(run["daily_modifier"] for run in daily_runs)
    if anomalies:
        lines += ["## Daily anomalies", "", "| Anomaly | Runs | Wins | Win rate | Mean wave |",
                  "|---|---:|---:|---:|---:|"]
        for name, count in anomalies.most_common():
            group = [run for run in daily_runs if run["daily_modifier"] == name]
            wins = sum(run["won"] for run in group)
            lines.append(
                f"| {markdown(name)} | {count} | {wins} | {pct(wins, count):.1f}% | "
                f"{statistics.mean([run['wave'] for run in group]):.1f} |"
            )
        lines.append("")
    refresh_total = sum(run["echo_refreshes"] for run in runs)
    if refresh_total:
        lines.append(f"Echo refreshes: **{refresh_total}** total · **{refresh_total / len(runs):.2f}** per run")
        lines.append("")
    contract_accepted = sum(run["contracts_accepted"] for run in runs)
    contract_completed = sum(run["contracts_completed"] for run in runs)
    contract_failed = sum(run["contracts_failed"] for run in runs)
    if contract_accepted:
        lines.append(
            f"Contracts: accepted **{contract_accepted}** · completed **{contract_completed}** · failed **{contract_failed}**"
        )
        lines.append("")

    boon_counts = Counter()
    for run in runs:
        boon_counts.update(run["boons"])
    if boon_counts:
        lines += ["## Boons", "", "| Boon | Picks |", "|---|---:|"]
        lines += [f"| {markdown(boon)} | {count} |" for boon, count in boon_counts.most_common()]
        lines.append("")

    by_char = defaultdict(list)
    for run in runs:
        by_char[run["character"]].append(run)
    lines += ["## By character", "", "| Character | Runs | Wins | Win rate | Mean wave | Median wave | Mean kills |", "|---|---:|---:|---:|---:|---:|---:|"]
    for character in sorted(by_char):
        group = by_char[character]
        char_wins = sum(run["won"] for run in group)
        waves = [run["wave"] for run in group]
        kills = [run["kills"] for run in group]
        lines.append(f"| {markdown(NAMES.get(character, character))} | {len(group)} | {char_wins} | {pct(char_wins, len(group)):.1f}% | {statistics.mean(waves):.1f} | {statistics.median(waves):g} | {statistics.mean(kills):.0f} |")
    lines.append("")

    losses = [run for run in runs if not run["won"]]
    if losses:
        deaths = Counter(run["wave"] for run in losses)
        lines += ["## Death waves", "", " · ".join(f"{wave}: {deaths[wave]}" for wave in sorted(deaths)), ""]

    weapon_stats = defaultdict(lambda: [0, 0])
    for run in runs:
        for weapon in set(run["weapons"]):
            weapon_stats[weapon][0] += 1
            weapon_stats[weapon][1] += run["won"]
    rows = [(weapon, count, weapon_wins, pct(weapon_wins, count)) for weapon, (count, weapon_wins) in weapon_stats.items() if count >= 3]
    if rows:
        rows.sort(key=lambda row: (-row[3], -row[1]))
        lines += ["## Weapons (runs with at least 3 appearances)", "", "| Weapon | Runs | Wins | Win rate |", "|---|---:|---:|---:|"]
        lines += [f"| {markdown(weapon)} | {count} | {weapon_wins} | {rate:.1f}% |" for weapon, count, weapon_wins, rate in rows]
        lines.append("")

    lines += ["## Recent runs", "", "| Seed | Character | Mode | Source | Build | Result | Wave | Kills | Refreshes | Time |", "|---:|---|---|---|---|---|---:|---:|---:|---:|"]
    for run in runs[-10:][::-1]:
        result = "WIN" if run["won"] else "loss"
        lines.append(f"| {markdown(run.get('seed', '?'))} | {markdown(NAMES.get(run['character'], run['character']))} | {_mode(run)} | {run['source']} | {markdown(run['build_commit'])} | {result} | {run['wave']} | {run['kills']} | {run['echo_refreshes']} | {run['seconds']:.0f}s |")
    lines.append("")

    joined, warnings = join_feedback(runs, feedback)
    if joined:
        lines += ["## Feedback", "", "| Seed | Character | Source | Wave | Category | Rating | Note |", "|---:|---|---|---:|---|---|---|"]
        for run, item in joined:
            lines.append(f"| {markdown(run.get('seed', '?'))} | {markdown(NAMES.get(run['character'], run['character']))} | {run['source']} | {run['wave']} | {item['category']} | {item['rating']} | {markdown(item['note'])} |")
        lines.append("")

    warning_lines = []
    if skipped_runs:
        warning_lines.append(f"Skipped {skipped_runs} malformed run record(s).")
    if skipped_feedback:
        warning_lines.append(f"Skipped {skipped_feedback} malformed feedback record(s).")
    if warnings["orphan"]:
        warning_lines.append(f"Ignored {warnings['orphan']} orphan feedback record(s) with no matching run.")
    if warnings["duplicate"]:
        warning_lines.append(f"Ignored {warnings['duplicate']} duplicate feedback record(s); duplicated runs were not joined.")
    if warnings["duplicate_run"]:
        warning_lines.append(f"Ignored feedback for {warnings['duplicate_run']} run record(s) with duplicate run IDs.")
    if warnings["mismatch"]:
        warning_lines.append(f"Ignored {warnings['mismatch']} feedback record(s) with mismatched run provenance.")
    if warning_lines:
        lines += ["## Data warnings", "", *warning_lines, ""]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", help="runs.jsonl files")
    parser.add_argument("--out", help="write Markdown to this file instead of stdout")
    parser.add_argument("--feedback", action="append", nargs="+", default=[], metavar="PATH", help="feedback JSONL path(s); may be repeated")
    parser.add_argument("--source", action="append", choices=SOURCES, help="include only this run source; may be repeated")
    args = parser.parse_args(argv)

    raw_runs, skipped_runs = load(args.paths)
    runs = []
    for record in raw_runs:
        item = norm(record)
        if item is None:
            skipped_runs += 1
        else:
            runs.append(item)
    feedback_paths = [path for group in args.feedback for path in group]
    raw_feedback, skipped_feedback = load(feedback_paths)
    feedback = []
    for record in raw_feedback:
        item = norm_feedback(record)
        if item is None:
            skipped_feedback += 1
        else:
            feedback.append(item)
    text = build_report(runs, skipped_runs, feedback, skipped_feedback, set(args.source or ()))
    if text is None:
        print("No valid runs.", file=sys.stderr)
        return 1
    if args.out:
        try:
            with open(args.out, "w", encoding="utf-8") as stream:
                stream.write(text + "\n")
        except OSError as exc:
            print(f"cannot write {args.out}: {exc}", file=sys.stderr)
            return 1
        print(f"wrote {args.out}")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
