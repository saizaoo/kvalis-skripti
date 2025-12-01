@echo off
REM Wazuh Active Response .cmd apvalks AD konta atslēgšanai (palaiž PowerShell skriptu).

setlocal
set "ARPATH=%ProgramFiles(x86)%\ossec-agent\active-response\bin"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ARPATH%\ar_disable_ad_user.ps1"
endlocal
