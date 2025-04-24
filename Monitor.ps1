<#
.SYNOPSIS
System Monitoring Script

.DESCRIPTION
This script monitors system performance, including CPU usage, memory utilization,
disk usage, uptime, battery, GPU, CPU temperature, and OS info.
It logs entries in "Monitor.txt" and can export CSV history (if -CSVLogging is used).

.PARAMETER CSVLogging
Switch to enable CSV logging (metrics_history.csv).

.PARAMETER HighCPUThreshold
CPU usage threshold for notifications (default: 80%).

.PARAMETER HighMemoryThreshold
Memory usage threshold for notifications (default: 80%).

.PARAMETER LowHealthThreshold
Health score threshold for notifications (default: 70%).

.EXAMPLE
.\SystemMonitor.ps1 -CSVLogging -HighCPUThreshold 85 -HighMemoryThreshold 85 -LowHealthThreshold 65
#>
param(
    [switch]$CSVLogging,
    [int]$HighCPUThreshold = 80,
    [int]$HighMemoryThreshold = 80,
    [int]$LowHealthThreshold = 70
)

# ---------------------------
# Global File Names
# ---------------------------
$logFile = "Monitor.txt"

# Create or initialize the monitor log file if needed.
if (-not (Test-Path $logFile)) {
    "Timestamp, CPU (%), Memory (Used/Total MB, %), Uptime, Disk Usage, GPU, Health Score, AI Recommendations" | Out-File $logFile
}

# ---------------------------
# Global Variables & Caches
# ---------------------------
if (-not $global:currentLogHour) {
    $global:currentLogHour = (Get-Date -Format "HH")
}
# Setup CSV history collection if enabled.
if ($CSVLogging) {
    $global:metricsHistory = @()
}

# For notification rate limiting (at most one every 60 seconds)
$global:lastNotificationTime = (Get-Date).AddSeconds(-60)

# Global anger counters for notifications
if (-not $global:cpuAngerLevel)    { $global:cpuAngerLevel = 0 }
if (-not $global:memoryAngerLevel) { $global:memoryAngerLevel = 0 }
if (-not $global:healthAngerLevel) { $global:healthAngerLevel = 0 }

# ---------------------------
# Helper Functions
# ---------------------------

# Show Desktop Notification (requires BurntToast if available)
function Show-Notification {
    param (
        [string]$Title,
        [string]$Message
    )
    try {
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast -ErrorAction SilentlyContinue
            New-BurntToastNotification -Text $Title, $Message
        } else {
            Write-Host "Notification: $Title - $Message"
        }
    }
    catch {
        Write-Host "Notification Error: $_"
    }
}

# Get CPU Temperature (if available via MSAcpi_ThermalZoneTemperature)
function Get-CPUTemperature {
    try {
        $tempObj = Get-WmiObject MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        if ($tempObj -and $tempObj.CurrentTemperature) {
            $celsius = ($tempObj.CurrentTemperature / 10) - 273.15
            return [math]::Round($celsius, 2)
        }
    } catch {
        return "N/A"
    }
    return "N/A"
}

# Get CPU Frequency (MHz) from WMI
function Get-CPUFrequency {
    try {
        $proc = Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue
        if ($proc -and $proc.CurrentClockSpeed) {
            return $proc.CurrentClockSpeed
        }
    } catch {
        return "N/A"
    }
    return "N/A"
}

# ---------------------------
# Main Loop
# ---------------------------
while ($true) {
    $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # === SYSTEM METRICS ===
    # CPU & Frequency
    $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time'
    $cpuUsage = [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
    $cpuFreq  = Get-CPUFrequency

    # Memory
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMemoryMB = [math]::Round($os.TotalVisibleMemorySize/1024,2)
    $freeMemoryMB  = [math]::Round($os.FreePhysicalMemory/1024,2)
    $usedMemoryMB  = [math]::Round($totalMemoryMB - $freeMemoryMB,2)
    $memoryUsagePercent = [math]::Round(($usedMemoryMB/$totalMemoryMB)*100,2)

    # Disk usage & Disk I/O counters
    $diskOutput = @()
    $diskUsages = @()
    $diskDrives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($drive in $diskDrives) {
        $device = $drive.DeviceID
        $totalSizeGB = [math]::Round($drive.Size/1GB,2)
        $freeSpaceGB = [math]::Round($drive.FreeSpace/1GB,2)
        $usedSpaceGB = [math]::Round($totalSizeGB - $freeSpaceGB,2)
        $usagePercent = if($totalSizeGB -gt 0){ [math]::Round(($usedSpaceGB/$totalSizeGB)*100,2) } else { 0 }
        $diskOutput += "Drive ${device}: ${usedSpaceGB}GB used / ${totalSizeGB}GB total (${usagePercent}% used)"
        $diskUsages += $usagePercent
    }
    $averageDiskUsage = if($diskUsages.Count -gt 0){ [math]::Round(($diskUsages | Measure-Object -Average).Average,2) } else { 0 }
    $diskRead  = Get-Counter '\PhysicalDisk(_Total)\Disk Read Bytes/sec' -ErrorAction SilentlyContinue
    $diskWrite = Get-Counter '\PhysicalDisk(_Total)\Disk Write Bytes/sec' -ErrorAction SilentlyContinue
    $readRate  = if($diskRead){ [math]::Round($diskRead.CounterSamples[0].CookedValue/1024,2) } else { "N/A" }
    $writeRate = if($diskWrite){ [math]::Round($diskWrite.CounterSamples[0].CookedValue/1024,2) } else { "N/A" }

    # Uptime & OS Info
    $uptimeTimespan = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptimeFormatted = "$($uptimeTimespan.Days)d $($uptimeTimespan.Hours)h $($uptimeTimespan.Minutes)m"
    $machineName = $env:COMPUTERNAME
    $osVersion   = (Get-CimInstance win32_operatingsystem).Caption

    # Battery, GPU, CPU Temperature and Gateway Latency
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    $batteryStatus = "N/A" # Default value
    if ($battery) {
        $batteryStatus = "$($battery.EstimatedChargeRemaining)%"
        # Get the battery status description.
        switch ($battery.BatteryStatus) {
            0 { $batteryStatus += " - Status: Other" }
            1 { $batteryStatus += " - Status: Discharging" }
            2 { $batteryStatus += " - Status: AC connected" }
            3 { $batteryStatus += " - Status: Fully charged" }
            4 { $batteryStatus += " - Status: Low" }
            5 { $batteryStatus += " - Status: Critical" }
            6 { $batteryStatus += " - Status: Charging" }
            7 { $batteryStatus += " - Status: Charging and High" }
            8 { $batteryStatus += " - Status: Charging and Low" }
            9 { $batteryStatus += " - Status: Charging and Critical" }
            default { $batteryStatus += " - Status: Unknown" }
        }
    }
    else
    {
        $batteryStatus = "N/A (Not a laptop)"
    }

    $gpuCounter = Get-Counter '\GPU Engine(_Total)\Utilization Percentage' -ErrorAction SilentlyContinue
    $gpuUsage = if($gpuCounter){ [math]::Round($gpuCounter.CounterSamples[0].CookedValue,2) } else { "N/A" }
    $cpuTemp = Get-CPUTemperature


    # === HEALTH SCORE & AI RECOMMENDATIONS ===
    $healthScore = 100 - ([math]::Round(($cpuUsage + $memoryUsagePercent + $averageDiskUsage)/3,2))
    if ($healthScore -lt 0) { $healthScore = 0 }
    $aiRecommendations = @()
    if ($cpuUsage -gt $HighCPUThreshold) { $aiRecommendations += "High CPU usage ($cpuUsage%). Close non-essential processes." }
    if ($memoryUsagePercent -gt $HighMemoryThreshold) { $aiRecommendations += "High Memory usage ($memoryUsagePercent%). Close memory‑intensive apps." }
    if ($battery -and $battery.EstimatedChargeRemaining -lt 20) { $aiRecommendations += "Battery low ($($battery.EstimatedChargeRemaining)%). Plug in charger." }
    if (($gpuUsage -ne "N/A") -and ($gpuUsage -gt 80)) { $aiRecommendations += "High GPU usage ($gpuUsage%)." }
    foreach ($drive in $diskDrives) {
        $device = $drive.DeviceID
        $totalSizeGB = [math]::Round($drive.Size/1GB,2)
        $freeSpaceGB = [math]::Round($drive.FreeSpace/1GB,2)
        $usedSpaceGB = [math]::Round($totalSizeGB - $freeSpaceGB,2)
        $usagePercent = if($totalSizeGB -gt 0){ [math]::Round(($usedSpaceGB/$totalSizeGB)*100,2) } else { 0 }
        if ($usagePercent -gt 90) { $aiRecommendations += "Drive ${device} nearly full (${usagePercent}% used)." }
    }
    if ($healthScore -lt $LowHealthThreshold) { $aiRecommendations += "Low system health ($healthScore/100). Consider restart/closing apps." }
    if ($aiRecommendations.Count -eq 0) { $aiRecommendations += "All systems optimal." }


    # === OPTIONAL CSV LOGGING ===
    if ($CSVLogging) {
        $entry = [pscustomobject]@{
            Timestamp             = $currentTime
            CPU_Usage             = $cpuUsage
            CPU_Frequency_MHz = $cpuFreq
            Memory_Used_MB      = $usedMemoryMB
            Total_Memory_MB     = $totalMemoryMB
            Memory_Percent      = $memoryUsagePercent
            Uptime                = $uptimeFormatted
            OS                  = "$osVersion on $machineName"
            Disk_Details          = ($diskOutput -join " | ") + " | Read: $readRate KB/s, Write: $writeRate KB/s"
            CPU_Temperature     = $cpuTemp
            GPU_Usage             = $gpuUsage
            Health_Score          = $healthScore
            AI_Recommendations  = ($aiRecommendations -join " ; ")
        }
        $global:metricsHistory += $entry
        if ($global:metricsHistory.Count -ge 50) {
            $global:metricsHistory | Export-Csv -Path "metrics_history.csv" -NoTypeInformation
            $global:metricsHistory = @()
        }
    }

    # === DESKTOP NOTIFICATIONS (rate-limited, once per 60 sec) with Increasing Anger ===
    $now = Get-Date
    if (($now - $global:lastNotificationTime).TotalSeconds -ge 60) {
        # CPU usage notification
        if ($cpuUsage -gt $HighCPUThreshold) {
            $global:cpuAngerLevel++
            $cpuMessage = "CPU usage is at $cpuUsage% (Freq: $cpuFreq MHz). " + ("Stop slacking! " * $global:cpuAngerLevel) + "Do something NOW!"
            Show-Notification -Title "High CPU Alert" -Message $cpuMessage
            $global:lastNotificationTime = $now
        }
        else {
            $global:cpuAngerLevel = 0
        }
        # Memory usage notification
        if ($memoryUsagePercent -gt $HighMemoryThreshold) {
            $global:memoryAngerLevel++
            $memMessage = "Memory usage is at $memoryUsagePercent%. " + ("Get your act together! " * $global:memoryAngerLevel) + "Fix it NOW!"
            Show-Notification -Title "High Memory Alert" -Message $memMessage
            $global:lastNotificationTime = $now
        }
        else {
            $global:memoryAngerLevel = 0
        }
        # System health notification
        if ($healthScore -lt $LowHealthThreshold) {
            $global:healthAngerLevel++
            $healthMessage = "System health is low ($healthScore/100). " + ("I'm getting REALLY pissed off! " * $global:healthAngerLevel) + "Do something NOW!"
            Show-Notification -Title "Low Health Score" -Message $healthMessage
            $global:lastNotificationTime = $now
        }
        else {
            $global:healthAngerLevel = 0
        }
    }

    # === BUILD DASHBOARD OUTPUT ===
    $output = @()
    $output += "================== SYSTEM MONITOR =================="
    $output += "$currentTime"
    $output += "Machine: $machineName | OS: $osVersion"
    $output += "-----------------------------------------------------------------"
    $output += "SYSTEM METRICS:"
    $output += "  CPU Usage: $cpuUsage% (Freq: $cpuFreq MHz) | Temp: $cpuTemp °C"
    $output += "  Memory: $usedMemoryMB MB / $totalMemoryMB MB ($memoryUsagePercent%)"
    $output += "  Uptime: $uptimeFormatted"
    $output += "  Disk Usage: " + ($diskOutput -join " || ")
    $output += "  Disk I/O: Read: $readRate KB/s, Write: $writeRate KB/s"
    $output += "  Battery: $batteryStatus"
    $output += "  GPU Usage: $gpuUsage %"
    $output += ""
    $output += "HEALTH SCORE: $healthScore/100"
    $output += "AI Recommendations:"
    $output += $aiRecommendations
    $output += "================================================================="

    # === DISPLAY (In-Place) ===
    [Console]::SetCursorPosition(0,0)
    $output | ForEach-Object { Write-Host $_ }
    $linesPrinted = $output.Count
    $windowHeight = [Console]::WindowHeight
    for ($i=0; $i -lt ($windowHeight-$linesPrinted); $i++) { Write-Host "" }

    # === APPEND TO MONITOR LOG (Hourly Grouping) ===
    $currentHour = (Get-Date -Format "HH")
    if ($global:currentLogHour -ne $currentHour) {
        Add-Content -Path $logFile -Value ""
        Add-Content -Path $logFile -Value ""
        Add-Content -Path $logFile -Value ""
        Add-Content -Path $logFile -Value "=== Entries for Hour $currentHour ==="
        $global:currentLogHour = $currentHour
    }
    $logEntry = "$currentTime, CPU: $cpuUsage%, Mem: $usedMemoryMB/$totalMemoryMB MB ($memoryUsagePercent%), Uptime: $uptimeFormatted, Disk: $([string]::Join(' || ', $diskOutput)), Health: $healthScore, AI: $($aiRecommendations -join ' ; ')"
    Add-Content -Path $logFile -Value $logEntry

    # === PAUSE BEFORE NEXT UPDATE ===
    Start-Sleep -Seconds 1.5
}
