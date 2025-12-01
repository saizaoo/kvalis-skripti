$pol = @(
    'Credential Validation',
    'Kerberos Authentication Service',
    'Kerberos Service Ticket Operations',
    'Other Account Logon Events',
    'Security Group Management',
    'User Account Management',
    'Computer Account Management',
    'Logon',
    'Logoff',
    'Special Logon',
    'Account Lockout',
    'File Share',
    'File System',
    'Directory Service Access',
    'Directory Service Changes',
    'Authentication Policy Change',
    'Authorization Policy Change',
    'Audit Policy Change',
    'Sensitive Privilege Use',
    'Process Creation'
)

foreach ($p in $pol) {
    auditpol /set /subcategory:"$p" /success:enable /failure:enable | Out-Null
}

New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1

$temp = Join-Path $env:TEMP 'sysmon'
New-Item -ItemType Directory -Path $temp -Force | Out-Null

Invoke-WebRequest -UseBasicParsing -Uri 'https://download.sysinternals.com/files/Sysmon.zip' -OutFile (Join-Path $temp 'Sysmon.zip')
Expand-Archive -LiteralPath (Join-Path $temp 'Sysmon.zip') -DestinationPath $temp -Force

Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/Neo23x0/sysmon-config/refs/heads/master/sysmonconfig-export.xml' -OutFile (Join-Path $temp 'sysmonconfig.xml')
Start-Process -FilePath (Join-Path $temp 'Sysmon64.exe') -ArgumentList '-accepteula -i', (Join-Path $temp 'sysmonconfig.xml') -Wait

$wazuhTemp = Join-Path $env:TEMP 'wazuh-agent'
New-Item -ItemType Directory -Path $wazuhTemp -Force | Out-Null

$wazuhMsi  = Join-Path $wazuhTemp 'wazuh-agent.msi'
Invoke-WebRequest -Uri 'https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.0-1.msi' -OutFile $wazuhMsi

$managerIp = '10.99.10.20'
$agentName =  $env:COMPUTERNAME

$msiArgs = "/i `"$wazuhMsi`" /q " + "WAZUH_MANAGER=`"$managerIp`" " + "WAZUH_AGENT_NAME=`"$agentName`""

Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -NoNewWindow

$ossecConf = 'C:\Program Files (x86)\ossec-agent\ossec.conf'

$snippet = @'
<ossec_config>
  <localfile>
    <log_format>eventchannel</log_format>
    <location>Security</location>
  </localfile>

  <localfile>
    <log_format>eventchannel</log_format>
    <location>System</location>
  </localfile>

  <localfile>
    <log_format>eventchannel</log_format>
    <location>Windows PowerShell</location>
  </localfile>

  <localfile>
    <log_format>eventchannel</log_format>
    <location>Microsoft-Windows-PowerShell/Operational</location>
  </localfile>

  <localfile>
    <log_format>eventchannel</log_format>
    <location>Microsoft-Windows-Sysmon/Operational</location>
  </localfile>
</ossec_config>
'@

if (-not (Select-String -Path $ossecConf -Pattern 'Microsoft-Windows-Sysmon/Operational' -Quiet)) {
    Add-Content -Path $ossecConf -Value "`r`n$snippet"
}

Start-Service wazuhsvc
Set-Service wazuhsvc -StartupType Automatic

