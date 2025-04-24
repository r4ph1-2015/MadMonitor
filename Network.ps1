<#
.SYNOPSIS
Network Monitoring Script

.DESCRIPTION
This script monitors network details, including active adapter IPs, WiFi SSID & signal,
TX/RX speeds, and connected devices.  It logs every new device in "devices_log.txt".

.EXAMPLE
.\NetworkMonitor.ps1
#>

# ---------------------------
# Global File Names
# ---------------------------
$devicesLogFile = "devices_log.txt"

# Create or initialize the devices log file.
if (-not (Test-Path $devicesLogFile)) {
    "Timestamp, Protocol, IP, MAC, Name, Status" | Out-File $devicesLogFile
}

# ---------------------------
# Global Variables & Caches
# ---------------------------
if (-not $global:prevNetStats)     { $global:prevNetStats = @{} }
if (-not $global:DevicesIPv4)        { $global:DevicesIPv4 = @() }
if (-not $global:DevicesIPv6)        { $global:DevicesIPv6 = @() }
if (-not $global:DeviceHistory)    { $global:DeviceHistory = @{} }  # Persistent device log
$updateCounter = 0

# ---------------------------
# Helper Functions
# ---------------------------

# Get Gateway Latency by pinging the default gateway.
function Get-GatewayLatency {
    try {
        $route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Where-Object { $_.NextHop -ne "0.0.0.0" } | Select-Object -First 1
        $gateway = $route.NextHop
        if ($gateway) {
            $pings = Test-Connection -ComputerName $gateway -Count 2 -ErrorAction SilentlyContinue
            if ($pings) {
                return [math]::Round(($pings | Measure-Object ResponseTime -Average).Average, 2)
            }
        }
    } catch {
        return "N/A"
    }
    return "N/A"
}

# Get WiFi details (SSID and signal strength) if available.
function Get-WiFiDetails {
    $wifiInfo = @{ SSID = "N/A"; Signal = "N/A" }
    try {
        $wlan = netsh wlan show interfaces 2>$null
        if ($wlan) {
            foreach ($line in $wlan) {
                if ($line -match "^\s*SSID\s*:\s*(.+)$") {
                    $wifiInfo.SSID = $matches[1].Trim()
                }
                if ($line -match "^\s*Signal\s*:\s*(\d+)%") {
                    $wifiInfo.Signal = "$($matches[1])%"
                }
            }
        }
    } catch {
        # nothing to do
    }
    return $wifiInfo
}

# Resolve device name for an IPv4 address using nbtstat.
function Get-DeviceName($ip) {
    try {
        $nbtOut = nbtstat -A $ip 2>&1
        foreach ($line in $nbtOut) {
            if ($line -match "^\s*(\S+)\s+<00>\s+UNIQUE") {
                return $matches[1]
            }
        }
    } catch {
        return "Unknown"
    }
    return "Unknown"
}

# ---------------------------
# Main Loop
# ---------------------------
while ($true) {
    $updateCounter++
    $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # === NETWORK ADAPTER DETAILS ===
    $netAdapterOutput = @()
    $activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $activeAdapters) {
        $ipConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex
        $ipv4Addresses = ($ipConfig.IPv4Address | ForEach-Object { $_.IPAddress }) -join ", "
        $ipv6Addresses = ($ipConfig.IPv6Address | ForEach-Object { $_.IPAddress }) -join ", "
        $currentStats = Get-NetAdapterStatistics -Name $adapter.Name
        if ($global:prevNetStats.ContainsKey($adapter.Name)) {
            $prev = $global:prevNetStats[$adapter.Name]
            $txRate = ([math]::Round(($currentStats.OutboundBytes - $prev.OutboundBytes)/1.5/1024,2))
            $rxRate = ([math]::Round(($currentStats.InboundBytes - $prev.InboundBytes)/1.5/1024,2))
            $txRateStr = "$txRate KB/s"
            $rxRateStr = "$rxRate KB/s"
        } else {
            $txRateStr = "N/A"
            $rxRateStr = "N/A"
        }
        $global:prevNetStats[$adapter.Name] = $currentStats
       
        # Process adapter LinkSpeed. If it's a string, extract the numeric portion.
        $linkSpeedMbps = "N/A"
        if ($adapter.LinkSpeed) {
            if ($adapter.LinkSpeed -is [string]) {
                if ($adapter.LinkSpeed -match '(\d+(\.\d+)?)') {
                    $speedValue = [double]$matches[1]
                    $linkSpeedMbps = "$([math]::Round($speedValue, 2)) Mbps"
                } else {
                    $linkSpeedMbps = "N/A"
                }
            }
            elseif ($adapter.LinkSpeed -is [numeric]) {
                $linkSpeedMbps = "$([math]::Round($adapter.LinkSpeed/1MB, 2)) Mbps"
            }
        } else {
            $linkSpeedMbps = "N/A"
        }
       
        $netAdapterOutput += "Adapter: $($adapter.Name) ($($adapter.InterfaceDescription)) | IPv4: ${ipv4Addresses} | IPv6: ${ipv6Addresses} | TX: $txRateStr, RX: $rxRateStr | Speed: $linkSpeedMbps"
    }

    # === CONNECTED DEVICES (Every 10 iterations) ===
    if ($updateCounter % 10 -eq 0) {
        # IPv4 Devices via ARP.
        $arpLines = arp -a | Where-Object { $_ -match "^\d{1,3}(\.\d{1,3}){3}" }
        $devicesIPv4 = @()
        foreach ($line in $arpLines) {
            $tokens = $line -split "\s+" | Where-Object { $_ -ne "" }
            if ($tokens.Count -ge 3) {
                $ip = $tokens[0]
                $mac = $tokens[1]
                $onlineStatus = if (Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1) { "Online" } else { "Offline" }
                $devName = Get-DeviceName $ip
                $devicesIPv4 += [pscustomobject]@{ IP=$ip; MAC=$mac; Status=$onlineStatus; Name=$devName }
            }
        }
        $global:DevicesIPv4 = $devicesIPv4

        # IPv6 Devices via netsh.
        $ipv6Lines = netsh interface ipv6 show neighbors 2>$null | Where-Object { $_ -match ":" }
        $devicesIPv6 = @()
        foreach ($line in $ipv6Lines) {
            $tokens = $line -split "\s+" | Where-Object { $_ -ne "" }
            if ($tokens.Count -ge 3 -and $tokens[0] -match ":") {
                $ip6 = $tokens[0]
                $mac = $tokens[1]
                $state = $tokens[-1]
                $devicesIPv6 += [pscustomobject]@{ IP=$ip6; MAC=$mac; Status=$state; Name="Unknown" }
            }
        }
        $global:DevicesIPv6 = $devicesIPv6

        # Log any new devices to devices_log.txt (only once per unique IP)
        foreach ($dev in $global:DevicesIPv4) {
            $key = "IPv4:$($dev.IP)"
            if (-not $global:DeviceHistory.ContainsKey($key)) {
                $global:DeviceHistory[$key] = $dev
                $line = "$currentTime, IPv4, IP: $($dev.IP), MAC: $($dev.MAC), Name: $($dev.Name), Status: $($dev.Status)"
                Add-Content -Path $devicesLogFile -Value $line
            }
        }
        foreach ($dev in $global:DevicesIPv6) {
            $key = "IPv6:$($dev.IP)"
            if (-not $global:DeviceHistory.ContainsKey($key)) {
                $global:DeviceHistory[$key] = $dev
                $line = "$currentTime, IPv6, IP: $($dev.IP), MAC: $($dev.MAC), Name: $($dev.Name), Status: $($dev.Status)"
                Add-Content -Path $devicesLogFile -Value $line
            }
        }
    }
    # Get Gateway Latency
    $gatewayLatency = Get-GatewayLatency

    # Get Wifi Details
    $wifiDetails = Get-WiFiDetails
    # === BUILD DASHBOARD OUTPUT ===
    $output = @()
    $output += "================== NETWORK MONITOR =================="
    $output += "$currentTime"
    $output += "----------------- NETWORK ADAPTERS ----------------------------"
    $output += $netAdapterOutput
    $output += ""
    $output += "Gateway Latency: $gatewayLatency ms"
    $output += "  WiFi: SSID=$($wifiDetails.SSID), Signal=$($wifiDetails.Signal)"
    $output += ""
    $output += "------------ CONNECTED DEVICES (IPv4) [ARP] ---------------------"
    if ($global:DevicesIPv4.Count -gt 0) {
        foreach ($dev in $global:DevicesIPv4) {
            $output += "  IP: $($dev.IP), MAC: $($dev.MAC), Status: $($dev.Status), Name: $($dev.Name)"
        }
    }
    else { $output += "  No IPv4 devices found." }
    $output += ""
    $output += "------------ CONNECTED DEVICES (IPv6) ---------------------------"
    if ($global:DevicesIPv6.Count -gt 0) {
        foreach ($dev in $global:DevicesIPv6) {
            $output += "  IP: $($dev.IP), MAC: $($dev.MAC), State: $($dev.Status), Name: $($dev.Name)"
        }
    }
    else { $output += "  No IPv6 devices found." }
    $output += "================================================================="

    # === DISPLAY (In-Place) ===
    [Console]::SetCursorPosition(0,0)
    $output | ForEach-Object { Write-Host $_ }
    $linesPrinted = $output.Count
    $windowHeight = [Console]::WindowHeight
    for ($i=0; $i -lt ($windowHeight-$linesPrinted); $i++) { Write-Host "" }

    # === PAUSE BEFORE NEXT UPDATE ===
    Start-Sleep -Seconds 1.5
}

