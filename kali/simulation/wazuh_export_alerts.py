import argparse
import csv
import sys
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

INDEXER_URL = "https://10.99.10.20:9200"
USER = "admin"
PASSWORD = "Bsb+?G4CmNJ.bS.R5u2Pby7Lf9yBYaxK"


def parse_args():
    p = argparse.ArgumentParser(
        description="Eksportē Wazuh bridinājumus uz CSV")
    p.add_argument("--rule-id", required=True,
                   help="Wazuh rule.id, piemēram, 100060, vai 10007*, vai '100071, 100072'")
    p.add_argument("--start", required=True,
                   help="Uzsākšanas laiks (ISO8601, piemēram 2025-11-20T18:00:00+02:00)")
    p.add_argument("--end", required=True,
                   help="Beigšanas laiks (ISO8601, piemēram 2025-11-20T18:10:00+02:00)")
    p.add_argument("--output", required=True,
                   help="Izvada CSV faila nosaukums")
    return p.parse_args()


def build_query(rule_id_arg, start, end):
    rule_id_arg = str(rule_id_arg).strip()

    if "," in rule_id_arg:
        ids = [x.strip() for x in rule_id_arg.split(",") if x.strip()]
        rule_clause = {"terms": {"rule.id": ids}}
    elif "*" in rule_id_arg or "?" in rule_id_arg:
        rule_clause = {"wildcard": {"rule.id": rule_id_arg}}
    else:
        rule_clause = {"term": {"rule.id": rule_id_arg}}

    return {
        "_source": True,
        "query": {
            "bool": {
                "must": [
                    rule_clause,
                    {"range": {"@timestamp": {"gte": start, "lte": end}}},
                ]
            }
        },
    }


def first_non_empty(values):
    for v in values:
        if v is not None and v != "":
            return v
    return None


def extract_ips(src):
    data_f = src.get("data", {}) or {}
    agent = src.get("agent", {}) or {}

    src_ip = first_non_empty([
        data_f.get("src_ip"),
        data_f.get("srcip"),
        data_f.get("source_ip"),
        src.get("srcip"),
    ])

    dst_ip = first_non_empty([
        data_f.get("dest_ip"),
        data_f.get("dstip"),
        data_f.get("destination_ip"),
        src.get("dstip"),
    ])

    win = data_f.get("win", {}) or {}
    eventdata = win.get("eventdata", {}) or {}

    if src_ip is None:
        src_ip = first_non_empty([
            eventdata.get("IpAddress"),
            eventdata.get("ipAddress"),
            eventdata.get("Ipaddress"),
        ])

    if dst_ip is None:
        dst_ip = agent.get("ip")

    return src_ip, dst_ip


def main():
    args = parse_args()

    indexer_url = INDEXER_URL.rstrip("/")
    search_url = f"{indexer_url}/wazuh-alerts-*/_search"

    query = build_query(args.rule_id, args.start, args.end)

    try:
        resp = requests.get(
            search_url,
            auth=(USER, PASSWORD),
            json=query,
            verify=False,
            timeout=30,
        )
        resp.raise_for_status()
    except Exception as e:
        print(f"Rādusies kļūda, nosūtot pieprāsījumu Wazuh indeksētājam: {
              e}", file=sys.stderr)
        sys.exit(1)

    data = resp.json()
    hits = data.get("hits", {}).get("hits", [])

    fieldnames = [
        "timestamp",
        "rule_id",
        "rule_description",
        "rule_level",
        "agent_name",
        "agent_id",
        "agent_ip",
        "src_ip",
        "dst_ip",
    ]

    with open(args.output, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        for h in hits:
            src = h.get("_source", {})
            rule = src.get("rule", {}) or {}
            agent = src.get("agent", {}) or {}

            src_ip, dst_ip = extract_ips(src)

            row = {
                "timestamp": src.get("@timestamp"),
                "rule_id": rule.get("id"),
                "rule_description": rule.get("description"),
                "rule_level": rule.get("level"),
                "agent_name": agent.get("name"),
                "agent_id": agent.get("id"),
                "agent_ip": agent.get("ip"),
                "src_ip": src_ip,
                "dst_ip": dst_ip,
            }
            writer.writerow(row)

        print(f"Uz {args.output} izvadīti {len(hits)} bridinājumi")


if __name__ == "__main__":
    main()
