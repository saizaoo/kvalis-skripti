Import-Module GroupPolicy

Install-WindowsFeature -Name FS-FileServer, Print-Server -IncludeManagementTools | Out-Null
Enable-WindowsOptionalFeature -Online -FeatureName Printing-PrintToPDFServices-Features -All -NoRestart | Out-Null

Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' | Out-Null

$ro = 'C:\LabShares\Tools'
$rw = 'C:\LabShares\Public'
New-Item -ItemType Directory -Path $ro,$rw -Force | Out-Null

icacls $ro /inheritance:e | Out-Null
icacls $ro /grant "LAB\Domain Admins:(OI)(CI)(F)" "LAB\Domain Users:(OI)(CI)(RX)" | Out-Null
icacls $rw /inheritance:e | Out-Null
icacls $rw /grant "LAB\Domain Admins:(OI)(CI)(F)" "LAB\Domain Users:(OI)(CI)(M)" | Out-Null

if (-not (Get-SmbShare -Name 'Tools' -ErrorAction SilentlyContinue)) {
  New-SmbShare -Name 'Tools' -Path $ro -FullAccess 'LAB\Domain Admins' -ReadAccess 'LAB\Domain Users' -CachingMode Documents | Out-Null
}
if (-not (Get-SmbShare -Name 'Public' -ErrorAction SilentlyContinue)) {
  New-SmbShare -Name 'Public' -Path $rw -FullAccess 'LAB\Domain Admins' -ChangeAccess 'LAB\Domain Users' -CachingMode Documents | Out-Null
}
Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing' | Out-Null

$netlogon = "\\lab.local\SYSVOL\lab.local\scripts"
New-Item -ItemType Directory -Path $netlogon -Force | Out-Null

$mapScript = @'
$maps = @(
    @{ Letter='P'; Path='\\dc-2019\Public' },
    @{ Letter='S'; Path='\\dc-2019\Tools'  }
)
foreach ($m in $maps) {
    if (Get-PSDrive -Name $m.Letter -ErrorAction SilentlyContinue) { continue }
    try {
        New-PSDrive -Name $m.Letter -PSProvider FileSystem -Root $m.Path -Persist -Scope Global | Out-Null
    } catch { }
}
'@

$mapScriptPath = Join-Path $netlogon 'MapDrives.ps1'
$mapScript | Out-File -FilePath $mapScriptPath -Encoding ASCII -Force

$gpoName = 'Map Shares'
$gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
if (-not $gpo) { $gpo = New-GPO -Name $gpoName }
$domainDN = (Get-ADDomain).DistinguishedName
New-GPLink -Name $gpo.DisplayName -Target $domainDN -Enforced No -ErrorAction SilentlyContinue | Out-Null

Set-GPRegistryValue -Name $gpoName -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run' -ValueName 'MapDrives' -Type String -Value 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File \\lab.local\NETLOGON\MapDrives.ps1'

gpupdate /force | Out-Null

Set-Service -Name Spooler -StartupType Automatic
Start-Service Spooler
if (-not (Get-Printer -Name 'LabPDF' -ErrorAction SilentlyContinue)) {
  Add-Printer -Name 'LabPDF' -DriverName 'Microsoft Print To PDF' -PortName 'PORTPROMPT:'
  Set-Printer  -Name 'LabPDF' -Shared $true -ShareName 'LAB-PDF'
}

$svcUser = 'svc_sql'
if (-not (Get-ADUser -Filter "SamAccountName -eq '$svcUser'" -ErrorAction SilentlyContinue)) {
  $pwd = ConvertTo-SecureString 'P@ssw0rd1!' -AsPlainText -Force
  New-ADUser -Name $svcUser -SamAccountName $svcUser -AccountPassword $pwd -Enabled $true -PasswordNeverExpires $true -Description 'Kerberoasting konts' | Out-Null
  setspn -S MSSQLSvc/dc-2019.lab.local:1433 LAB\$svcUser | Out-Null
  setspn -S MSSQLSvc/dc-2019.lab.local LAB\$svcUser | Out-Null
  Set-ADUser $svcUser -Add @{ 'msDS-SupportedEncryptionTypes' = 4 } # 4 = RC4-HMAC
}

$asrep = 'asrep_user'
if (-not (Get-ADUser -Filter "SamAccountName -eq '$asrep'" -ErrorAction SilentlyContinue)) {
  $pwd2 = ConvertTo-SecureString 'P@ssw0rd2!' -AsPlainText -Force
  New-ADUser -Name $asrep -SamAccountName $asrep -AccountPassword $pwd2 -Enabled $true -PasswordNeverExpires $true -Description 'AS-REP roasting konts' | Out-Null
  Set-ADAccountControl -Identity $asrep -DoesNotRequirePreAuth $true
}

$rep = 'replication_test'
if (-not (Get-ADUser -Filter "SamAccountName -eq '$rep'" -ErrorAction SilentlyContinue)) {
  $pwd3 = ConvertTo-SecureString 'P@ssw0rd3!' -AsPlainText -Force
  New-ADUser -Name $rep -SamAccountName $rep -AccountPassword $pwd3 -Enabled $true -PasswordNeverExpires $true -Description 'DCSync rights only' | Out-Null
  dsacls "DC=lab,DC=local" /G "LAB\replication_test:CA;Replicating Directory Changes" | Out-Null
  dsacls "DC=lab,DC=local" /G "LAB\replication_test:CA;Replicating Directory Changes All" | Out-Null
  dsacls "DC=lab,DC=local" /G "LAB\replication_test:CA;Replicating Directory Changes In Filtered Set" | Out-Null
}
