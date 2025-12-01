#!/bin/bash

set -euo pipefail

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo "Lietojums: $0 <attack_script> <rule_id_vai_wildcard> <scenario_id> <output_dir> [attack_arg]"
  echo "Piemērs: $0 ./rdp_bruteforce.sh '10001*' rdp_bruteforce_small ./results passlist.txt"
  exit 1
fi

ATTACK_SCRIPT="$1"
RULE_ID="$2"
SCENARIO_BASE="$3"
OUT_DIR="$4"
ATTACK_ARG="${5:-}"

RUNS=5

SLEEP_AFTER_ATTACK=30 # cik sekundes gaidīt, lai Wazuh paspēj indeksēt
SLEEP_BETWEEN_RUNS=30 # pauze starp palaidieniem

SCENARIO_LOG="scenario.log"
PY_QUERY_SCRIPT="./wazuh_export_alerts.py"
PY_METRICS_SCRIPT="./calc_metrics.py"

mkdir -p "$OUT_DIR"

for i in $(seq 1 "$RUNS"); do
  SCENARIO_ID="${SCENARIO_BASE}_${i}"
  echo '------------------------------'
  echo "Palaists scenārijs: ${SCENARIO_ID}"
  echo "Uzbrukuma skripts: ${ATTACK_SCRIPT}"
  echo "Filtrējamie noteikumi (rule.id): ${RULE_ID}"

  if [ -n "$ATTACK_ARG" ]; then
    # Piemēram RDP paroļu pārlase: ./rdp_bruteforce_scenario.sh <wordlist> <scenario_id>
    "$ATTACK_SCRIPT" "$ATTACK_ARG" "$SCENARIO_ID"
  else
    # Scenārijiem, kas neprasa papildus argumentus
    "$ATTACK_SCRIPT" "$SCENARIO_ID"
  fi

  echo "Gaida ${SLEEP_AFTER_ATTACK}s, lai Wazuh savāktu notikumus..."
  sleep "$SLEEP_AFTER_ATTACK"

  if [ ! -f "$SCENARIO_LOG" ]; then
    echo "Kļūda: nav atrasts ${SCENARIO_LOG} fails" >&2
    exit 1
  fi

  START_TIME=$(grep "scenario=${SCENARIO_ID}," "$SCENARIO_LOG" | grep "status=start" | tail -n 1 | cut -d',' -f1)
  END_TIME_RAW=$(grep "scenario=${SCENARIO_ID}," "$SCENARIO_LOG" | grep "status=end" | tail -n 1 | cut -d',' -f1)

  if [ -z "${START_TIME}" ] || [ -z "${END_TIME_RAW}" ]; then
    echo "Kļūda: nevar nolasīt start/end laiku scenārijam ${SCENARIO_ID}" >&2
    exit 1
  fi

  END_TIME=$(date -Is -d "${END_TIME_RAW} +${SLEEP_AFTER_ATTACK} seconds")

  echo "Starta laiks: ${START_TIME}"
  echo "Beigu laiks: ${END_TIME}"

  OUT_FILE="${OUT_DIR}/${SCENARIO_ID}.csv"

  echo "Vaicā Wazuh brīdinājumus (rule.id=${RULE_ID}) un rakstu: ${OUT_FILE}"

  python "$PY_QUERY_SCRIPT" --rule-id "$RULE_ID" --start "$START_TIME" --end "$END_TIME" --output "$OUT_FILE"

  echo "Scenārijs ${SCENARIO_ID} pabeigts."
  if [ "$i" -lt "$RUNS" ]; then
    echo "Gaida ${SLEEP_BETWEEN_RUNS}s pirms nākamā palaidiena..."
    sleep "$SLEEP_BETWEEN_RUNS"
  fi
done

echo "Visi ${RUNS} palaidieni pabeigti. Aprēķina mērījumus..."

python "$PY_METRICS_SCRIPT" --scenario-base "$SCENARIO_BASE" --rule-id-pattern "$RULE_ID" --out-dir "$OUT_DIR" --runs "$RUNS" --scenario-log "$SCENARIO_LOG"

