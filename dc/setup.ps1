New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 10.99.10.10 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 10.99.10.10

Set-NetIPInterface -InterfaceAlias "Ethernet0" -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias "Ethernet1" -InterfaceMetric 50

route -p ADD 10.99.20.0 MASK 255.255.255.0 10.99.10.254
route -p ADD 10.99.99.0 MASK 255.255.255.252 10.99.10.254

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

$securePwd = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
Install-ADDSForest -DomainName "lab.local" -SafeModeAdministratorPassword $securePwd -InstallDns -Force -NoRebootOnCompletion

Install-WindowsFeature -Name DHCP -IncludeManagementTools

$stage2 = 'E:\stage2.ps1'
if (Test-Path $stage2) {
    New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" `
        -Name "Stage2" `
        -Value "powershell.exe -ExecutionPolicy Bypass -File `"$stage2`"" `
        -PropertyType String | Out-Null
}

$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $regPath -Name 'AutoAdminLogon' -Value '1' -Type String
Set-ItemProperty -Path $regPath -Name 'DefaultUsername' -Value 'Administrator' -Type String
Set-ItemProperty -Path $regPath -Name 'DefaultPassword' -Value 'P@ssw0rd!' -Type String

Restart-Computer -Force
