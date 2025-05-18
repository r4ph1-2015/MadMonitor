# Mad Monitor V2.1 - Static Table, Live Value Update, and Auto-Update Feature (1-minute refresh)

$LocalVersion = "V2.1"
$VersionUrl   = "https://raw.githubusercontent.com/r4ph1-2015/MadMonitor/main/Version.txt"
$ScriptUrl    = "https://raw.githubusercontent.com/r4ph1-2015/MadMonitor/main/Monitor.ps1"

function Check-ForUpdate {
    try {
        $onlineVersion = (Invoke-WebRequest -Uri $VersionUrl -UseBasicParsing -TimeoutSec 5).Content.Trim()
        if ($onlineVersion -ne $LocalVersion) {
            [Console]::SetCursorPosition(0,0)
            Write-Host "`nA new version of Mad Monitor is available! ($onlineVersion)" -ForegroundColor Yellow
            Write-Host "You are running version $LocalVersion." -ForegroundColor Yellow
            $answer = Read-Host "Would you like to update now? (y/n)"
            if ($answer -eq 'y' -or $answer -eq 'Y') {
                $scriptPath = $MyInvocation.MyCommand.Definition
                Invoke-WebRequest -Uri $ScriptUrl -OutFile "$scriptPath.tmp"
                Move-Item -Path "$scriptPath.tmp" -Destination $scriptPath -Force
                Write-Host "Update complete. Please restart the script." -ForegroundColor Green
                exit
            } else {
                Write-Host "Continuing with current version." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
    } catch {
        Write-Host "Could not check for updates: $_" -ForegroundColor DarkYellow
        Start-Sleep -Seconds 2
    }
}

Check-ForUpdate

$PollingInterval = 60  # <-- Refresh every 1 minute

$ResourcesToMonitor = @(
    @{
        Name               = "CPU Usage (%)"
        Script             = { [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue, 2) }
        Threshold          = 85
        AlertType          = "High CPU"
        ComparisonOperator = "gt"
        Enabled            = $true
    }
    @{
        Name               = "Memory Usage (%)"
        Script             = { 
            $os = Get-CimInstance Win32_OperatingSystem
            [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 2)
        }
        Threshold          = 90
        AlertType          = "High Memory"
        ComparisonOperator = "gt"
        Enabled            = $true
    }
    @{
        Name               = "Disk C: Free Space (%)"
        Script             = { 
            $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
            [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 2)
        }
        Threshold          = 10
        AlertType          = "Low Disk Space"
        ComparisonOperator = "lt"
        Enabled            = $true
    }
)

function Get-ResourceUsage {
    param([ScriptBlock]$Script)
    try { return (& $Script) }
    catch { return $null }
}

# Print static header and table structure ONCE
Clear-Host
Write-Host "Mad Monitor V2.1 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ("".PadRight(72,"-"))
Write-Host ("{0,-25}{1,-20}{2,-20}" -f "Resource", "Value", "Threshold")
Write-Host ("".PadRight(72,"-"))

# Print placeholders for values, record Y positions
$rowMap = @()
foreach ($resource in $ResourcesToMonitor) {
    if ($resource.Enabled -ne $false) {
        $resourceName = $resource.Name
        $resourceThreshold = $resource.Threshold
        $y = [Console]::CursorTop
        Write-Host ("{0,-25}{1,-20}{2,-20}" -f $resourceName, "--", $resourceThreshold)
        $rowMap += @{Y=$y; Name=$resourceName; Resource=$resource}
    }
}
$footerY = [Console]::CursorTop
Write-Host ("".PadRight(72,"-"))
Write-Host ("Updating every ${PollingInterval}s (every 1 minute). Press Ctrl+C to exit.")

# Check for updates every minute
$lastUpdateCheck = Get-Date
$updateIntervalMinutes = 1

while ($true) {
    # Periodic update check
    if ((New-TimeSpan -Start $lastUpdateCheck -End (Get-Date)).TotalMinutes -ge $updateIntervalMinutes) {
        Check-ForUpdate
        $lastUpdateCheck = Get-Date
    }

    foreach ($row in $rowMap) {
        $y = $row.Y
        $resource = $row.Resource
        $resourceValue = Get-ResourceUsage -Script $resource.Script
        [Console]::SetCursorPosition(25, $y) # value column
        if ($resourceValue -ne $null) {
            $out = ("{0,-20}" -f $resourceValue)
        } else {
            $out = ("{0,-20}" -f "N/A")
        }
        Write-Host $out -NoNewline
    }
    Start-Sleep -Seconds $PollingInterval
}