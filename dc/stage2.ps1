# gaida līdz AD DS pakalpojums kļūst pieejams
Start-Sleep -Seconds 60

Enable-PSRemoting -Force

netsh dhcp add securitygroups
Restart-Service dhcpserver

Set-DhcpServerv4Binding -BindingState $true -InterfaceAlias "Ethernet0" | Out-Null

Add-DhcpServerInDC -DnsName "lab.local" -IpAddress 10.99.10.10

# DHCP ir tikai priekš klientiem, kuru ir 3. Pārējām virtuālām mašīnam uzstādīts statiska IP adrese
Add-DhcpServerv4Scope -Name "LabScope" -StartRange 10.99.20.11 -EndRange 10.99.20.13 -SubnetMask 255.255.255.0
Set-DhcpServerv4OptionValue -ScopeId 10.99.20.0 -Router 10.99.20.254 -DnsServer 10.99.10.10
Set-DhcpServerv4Scope -ScopeId 10.99.20.0 -State Active
Restart-Service dhcpserver

Set-DnsServerForwarder -IPAddress 8.8.8.8,8.8.4.4
Set-DnsClient -InterfaceAlias "Ethernet1" -RegisterThisConnectionsAddress $false -UseSuffixWhenRegistering $false
Set-DnsClient -InterfaceAlias "Ethernet0" -RegisterThisConnectionsAddress $true
ipconfig /flushdns
ipconfig /registerdns
Restart-Service netlogon

$vmTools = Get-PSDrive -PSProvider FileSystem | Where-Object {
    Test-Path (Join-Path $_.Root "setup64.exe")
}
if ($vmTools) {
    $installer = Join-Path $vmTools.Root "setup64.exe"
    Start-Process -FilePath $installer -ArgumentList "/S /v`"/qn REBOOT=R`"" -Wait
}

$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Remove-ItemProperty -Path $regPath -Name 'AutoAdminLogon','DefaultUsername','DefaultPassword' -ErrorAction SilentlyContinue
