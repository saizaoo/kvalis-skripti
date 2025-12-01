param(
    [Parameter(Mandatory = $true)]
    [string]$IpInput
)

# Normalizē IP (izmet /masku, ja ir)
$TargetIp = $IpInput.Split('/')[0]

# Pārbauda, vai IP adrese ir derīga
if (-not ($TargetIp -as [System.Net.IPAddress])) {
    Write-Host "Norādītā IP adrese nav derīga: $IpInput"
    exit 1
}

try {
    # Atlasa tikai Wazuh AR izveidotos noteikumus
    $wazuhRules = Get-NetFirewallRule -DisplayName 'WAZUH ACTIVE RESPONSE BLOCKED IP' -ErrorAction SilentlyContinue

    if (-not $wazuhRules) {
        Write-Host "Nav atrasts neviens ugunsmūra noteikums ar nosaukumu 'WAZUH ACTIVE RESPONSE BLOCKED IP'."
        exit 0
    }

    # Filtrē pēc IP adreses
    $rulesToRemove = @()

    foreach ($rule in $wazuhRules) {
        $addrFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue
        if (-not $addrFilter) { continue }

        $match = $false

        foreach ($raw in $addrFilter.RemoteAddress) {
            # Normalizē IP (10.99.20.30/32 -> 10.99.20.30)
            $normalized = ($raw -split '/')[0]
            if ($normalized -eq $TargetIp) {
                $match = $true
                break
            }
        }

        if ($match) {
            $rulesToRemove += $rule
        }
    }

    if (-not $rulesToRemove) {
        Write-Host "Nav atrasts neviens 'WAZUH ACTIVE RESPONSE BLOCKED IP' noteikums ar IP $TargetIp."
        exit 0
    }

    Write-Host "Noņem ugunsmūra noteikumus 'WAZUH ACTIVE RESPONSE BLOCKED IP' ar IP $TargetIp..."
    $rulesToRemove | Remove-NetFirewallRule -ErrorAction Stop
    Write-Host "IP $TargetIp ir atbloķēts."
}
catch {
    $msg = "Kļūda, mēģinot atbloķēt IP {0}: {1}" -f $TargetIp, $_.Exception.Message
    Write-Host $msg
    exit 1
}

