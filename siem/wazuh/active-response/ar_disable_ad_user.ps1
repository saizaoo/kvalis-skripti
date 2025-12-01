# Wazuh Active Response skripts AD lietotāja atspējošanai

param()

$ErrorActionPreference = 'Stop'

# Ceļš uz Active Response žurnālu priekš paštaisītiem skriptiem
$LOG_FILE = "C:\Program Files (x86)\ossec-agent\active-response\custom-active-responses.log"

$fullPath = $MyInvocation.MyCommand.Path
$idx = $fullPath.IndexOf("active-response")
if ($idx -ge 0) {
    $script:ScriptRelPath = $fullPath.Substring($idx).Replace('\', '/')
}
else {
    $script:ScriptRelPath = "active-response/bin/" + $MyInvocation.MyCommand.Name
}

$ADD_COMMAND = "add"
$CONTINUE_COMMAND = "continue"

function Write-ArLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        $timestamp = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
        $line = "$timestamp $($script:ScriptRelPath): $Message"
        Add-Content -LiteralPath $LOG_FILE -Value $line
    }
    catch {
    }
}

function Read-JsonLine {
    try {
        $line = [Console]::In.ReadLine()
    }
    catch {
        Write-ArLog "Kļūda, lasot STDIN: $_"
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($line)) {
        return $null
    }

    Write-ArLog $line

    try {
        return $line | ConvertFrom-Json
    }
    catch {
        Write-ArLog "Kļūda, parsējot JSON: $_"
        return $null
    }
}

function Get-TargetUserFromAlert {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Alert
    )

    # Pamatstruktūra: data.win.eventdata.targetUserName (Windows eventchannel)
    if ($Alert.data -and $Alert.data.win -and $Alert.data.win.eventdata) {
        $u = $Alert.data.win.eventdata.targetUserName
        if (-not $u) { $u = $Alert.data.win.eventdata.TargetUserName }
        if ($u) { return ($u.Trim()) }
    }

    # Rezerves varianti, ja struktūra ir citāda
    if ($Alert.win -and $Alert.win.eventdata) {
        $u = $Alert.win.eventdata.targetUserName
        if (-not $u) { $u = $Alert.win.eventdata.TargetUserName }
        if ($u) { return ($u.Trim()) }
    }

    $prop = $Alert.PSObject.Properties['win.eventdata.targetUserName']
    if ($prop -and $prop.Value) {
        return ($prop.Value.ToString().Trim())
    }

    return $null
}

function Build-CheckKeysMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Keys
    )

    $obj = [ordered]@{
        version = 1
        origin = @{
            name = $script:ScriptRelPath
            module = "active-response"
        }
        command = "check_keys"
        parameters = @{
            keys = $Keys
        }
    }

    return ($obj | ConvertTo-Json -Compress)
}

# Sākotnējais JSON no wazuh-execd
$data = Read-JsonLine
if (-not $data) {
    Write-ArLog "Nav derīga sākotnējā JSON ziņojuma. Skripts beidzas."
    exit 0
}

$command = $data.command
if (-not $command) {
    Write-ArLog "JSON ziņojumā nav 'command' lauka. Skripts beidzas."
    exit 0
}

if (-not $data.parameters -or -not $data.parameters.alert) {
    Write-ArLog "JSON ziņojumā nav 'parameters.alert' objekta. Skripts beidzas."
    exit 0
}

$alert = $data.parameters.alert

# Izvelk mērķa lietotāju
$targetUserName = Get-TargetUserFromAlert -Alert $alert
if (-not $targetUserName) {
    Write-ArLog "Brīdinājuma nav atrasts 'targetUserName'. Nekas netiek darīts."
    exit 0
}

Write-ArLog "Saņemts lietotājs no brīdinājuma: '$targetUserName' (command='$command')."

# Veic check_keys tikai 'add' gadījumā
if ($command -ne $ADD_COMMAND) {
    Write-ArLog "Komanda nav '$ADD_COMMAND' (ir '$command'). AD konts netiek mainīts."
    exit 0
}

# Uzbūvē un izsūta check_keys ziņojumu
$keys = @($targetUserName)
$keysMsg = Build-CheckKeysMessage -Keys $keys

Write-ArLog $keysMsg

[Console]::Out.WriteLine($keysMsg)
[Console]::Out.Flush()

# Sagaida execd atbildi (continue/abort)
$response = Read-JsonLine
if (-not $response) {
    Write-ArLog "Nesaņemta derīga atbilde uz 'check_keys'. Skripts beidzas."
    exit 0
}

if ($response.command -ne $CONTINUE_COMMAND) {
    Write-ArLog "Wazuh atbildēja ar '$($response.command)'. AD konts '$targetUserName' netiek mainīts."
    exit 0
}

# Atspējo AD kontu
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-ArLog "Neizdevās ielādēt ActiveDirectory moduli: $_"
    exit 0
}

try {
    $adUser = Get-ADUser -Identity $targetUserName -ErrorAction Stop
}
catch {
    Write-ArLog "AD lietotājs '$targetUserName' nav atrasts: $_"
    exit 0
}

try {
    if (-not $adUser.Enabled) {
        Write-ArLog "Lietotājs '$targetUserName' jau ir atspējots. Nekas netiek mainīts."
    }
    else {
        Disable-ADAccount -Identity $adUser -ErrorAction Stop

        # Pievieno īsu iemeslu aprakstam
        $ruleId = $alert.rule.id
        $agentName = $alert.agent.name
        $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        $reason = "Konts atslēgts ar Wazuh Active Response (rule $ruleId, aģents $agentName, $time)"

        $newDescription = if ([string]::IsNullOrWhiteSpace($adUser.Description)) {
            $reason
        }
        else {
            "$($adUser.Description) | $reason"
        }

        Set-ADUser -Identity $adUser -Description $newDescription -ErrorAction Stop

        Write-ArLog "Lietotājs '$targetUserName' ir atspējots un apraksts atjaunināts."
    }
}
catch {
    Write-ArLog "Kļūda, atspējot vai atjauninot lietotāju '$targetUserName': $_"
}

exit 0
