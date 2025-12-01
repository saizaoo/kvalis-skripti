#!/usr/bin/env python3

import argparse
import csv
import os
import sys
from datetime import datetime
from collections import defaultdict


def parse_args():
    p = argparse.ArgumentParser(
        description="Aprēķina mērījumus no scenārija CSV failiem")
    p.add_argument("--scenario-base", required=True,
                   help="Scenārija ID, piemēram, rdp_bruteforce_small)")
    p.add_argument("--rule-id-pattern", required=True,
                   help="Wazuh rule.id, piemēram, 100060, vai 10007*, vai '100071, 100072'")
    p.add_argument("--out-dir", required=True,
                   help="Direktorija, kur glabājas CSV faili")
    p.add_argument("--runs", type=int, required=True,
                   help="Cik palaidienu tika veikti")
    p.add_argument("--scenario-log", required=True,
                   help="scenario.log fails ar start/end ierakstiem")
    return p.parse_args()


def parse_iso(ts):
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    return datetime.fromisoformat(ts)


def load_start_times(log_path):
    start_times = {}
    try:
        with open(log_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if "status=start" not in line or "scenario=" not in line:
                    continue
                parts = line.split(",")
                ts = parts[0]
                scenario_id = None
                for p in parts:
                    if p.startswith("scenario="):
                        scenario_id = p.split("=", 1)[1]
                        break
                if scenario_id:
                    start_times[scenario_id] = ts
    except FileNotFoundError:
        print(f"Kļūda: nav atrasts scenario.log: {log_path}", file=sys.stderr)
        sys.exit(1)
    return start_times


def fmt_dec(num, digits):
    if num is None:
        return "-"
    s = f"{num:.{digits}f}"
    return s.replace(".", ",")


def main():
    args = parse_args()
    scenario_base = args.scenario_base
    rule_pattern = args.rule_id_pattern
    out_dir = args.out_dir
    runs = args.runs
    scenario_log = args.scenario_log

    start_times = load_start_times(scenario_log)

    rule_stats = defaultdict(
        lambda: {"runs_detected": 0, "total_alerts": 0, "ttd_sum": 0.0, "ttd_count": 0})
    total_runs = runs
    total_key = "TOTAL"

    for i in range(1, runs + 1):
        scenario_id = f"{scenario_base}_{i}"
        start_ts_str = start_times.get(scenario_id)
        if not start_ts_str:
            print(f"Brīdinājums: scenārijam {
                  scenario_id} nav starta laika scenario.log failā", file=sys.stderr)
            continue
        start_time = parse_iso(start_ts_str)

        csv_path = os.path.join(out_dir, f"{scenario_id}.csv")
        if not os.path.exists(csv_path):
            print(f"Brīdinājums: nav atrasts CSV fails {
                  csv_path}", file=sys.stderr)
            continue

        per_run_counts = defaultdict(int)
        per_run_first = {}

        any_count = 0
        any_first = None

        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                rid = row.get("rule_id")
                ts = row.get("timestamp")
                if not rid or not ts:
                    continue
                try:
                    alert_time = parse_iso(ts)
                except Exception:
                    continue

                any_count += 1
                if any_first is None or alert_time < any_first:
                    any_first = alert_time

                per_run_counts[rid] += 1
                if rid not in per_run_first or alert_time < per_run_first[rid]:
                    per_run_first[rid] = alert_time

        if any_count > 0:
            per_run_counts[total_key] += any_count
            per_run_first[total_key] = any_first

        for rid, count in per_run_counts.items():
            stats = rule_stats[rid]
            if count > 0:
                stats["runs_detected"] += 1
                stats["total_alerts"] += count
                first_time = per_run_first.get(rid)
                if first_time:
                    ttd = (first_time - start_time).total_seconds()
                    stats["ttd_sum"] += ttd
                    stats["ttd_count"] += 1

    keys = list(rule_stats.keys())
    if total_key in keys:
        keys.remove(total_key)
    rule_keys = sorted(keys, key=lambda x: int(x) if x.isdigit() else x)

    many_rules = len(rule_keys) > 1
    if many_rules and total_key in rule_stats:
        rule_keys_with_total = rule_keys + [total_key]
    else:
        rule_keys_with_total = rule_keys

    rows = []
    for rid in rule_keys_with_total:
        stats = rule_stats[rid]
        runs_detected = stats["runs_detected"]
        detection_rate = (runs_detected / total_runs *
                          100.0) if total_runs > 0 else 0.0
        mean_alerts = (stats["total_alerts"] /
                       total_runs) if total_runs > 0 else 0.0
        if stats["ttd_count"] > 0:
            mean_ttd = stats["ttd_sum"] / stats["ttd_count"]
        else:
            mean_ttd = None

        display_rid = "KOPĀ" if rid == total_key else rid

        rows.append({
            "scenario": scenario_base,
            "rule": display_rid,
            "runs_detected": runs_detected,
            "total_runs": total_runs,
            "rate": detection_rate,
            "ttd": mean_ttd,
            "alerts": mean_alerts,
        })

    print(f"Scenārijs: {scenario_base} (palaidieni: {
          total_runs}), rule.id: {rule_pattern}")
    print()
    print("| Scenārijs | Noteikuma ID | Atklāti uzbrukumi / visi | Atklāšanas līmenis (%) | Vid. atklāšanas laiks (s) | Vid. brīdinājumi palaidienā |")
    print("|-----------|--------------|--------------------------|-------------------------|----------------------------|-----------------------------|")

    for r in rows:
        rate_str = fmt_dec(r["rate"], 1)
        ttd_str = "-" if r["ttd"] is None else fmt_dec(r["ttd"], 1)
        alerts_str = fmt_dec(r["alerts"], 2)
        print(f"| {r['scenario']} | {r['rule']} | {r['runs_detected']
                                                   } / {r['total_runs']} | {rate_str} | {ttd_str} | {alerts_str} |")


if __name__ == "__main__":
    main()
