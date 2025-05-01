<#
.SYNOPSIS
    Monitors system resources and triggers alerts based on defined thresholds.

.DESCRIPTION
    This script monitors various system resources (e.g., CPU usage, memory usage, disk space, battery status)
    and triggers alerts when specified thresholds are exceeded. It is designed to be
    customizable and extensible.

.NOTES
    Author: [Your Name]
    Version: 2.0
    Date: [Current Date]
#>

#region Configuration

# Configuration Section
# ---------------------
#  This section defines the parameters and settings for the script.
#  It should be easily customizable by the user.

# Define resources to monitor and their thresholds
$ResourcesToMonitor = @(
    @{
        Name              = "CPU Usage";
        Script            = {
            Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1 |
            Select-Object -ExpandProperty CounterSamples |
            Select-Object -ExpandProperty CookedValue
        };
        Threshold         = 80;    # Percentage
        AlertType         = "High CPU Usage";
        ComparisonOperator = "GreaterThan";
    },
    @{
        Name              = "Memory Usage";
        Script            = {
            Get-Counter -Counter "\Memory\Available MBytes" -SampleInterval 1 -MaxSamples 1 |
            Select-Object -ExpandProperty CounterSamples |
            Select-Object -ExpandProperty CookedValue
        };
        Threshold         = 500;   # MB
        AlertType         = "Low Memory";
        ComparisonOperator = "LessThan";
    },
    @{
        Name              = "Disk Space (C:)";
        Script            = {
            Get-PSDrive -PSProvider FileSystem |
            Where-Object { $_.Root -eq "C:" } |
            Select-Object FreeSpace |
            ForEach-Object { $_.FreeSpace / 1GB }
        };
        Threshold         = 20;    # GB
        AlertType         = "Low Disk Space";
        ComparisonOperator = "LessThan";
    },
    @{ # Added Battery Monitoring
        Name              = "Battery Level";
        Script            = {
            $batteryInfo = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
            if ($batteryInfo) {
                #check if battery level is null or empty
                if ($batteryInfo.BatteryLevel -eq $null -or $batteryInfo.BatteryLevel -eq ""){
                    Write-Warning "Battery Level is not available"
                    return $null
                }
                else{
                  return $batteryInfo.BatteryLevel
                }

            }
            else {
                Write-Warning "No battery information available."
                return $null
            }
        };
        Threshold         = 20;    # Percentage
        AlertType         = "Low Battery";
        ComparisonOperator = "LessThan";
        Enabled           = $true; # You can disable this if needed
    }
)

# Define notification methods
$NotificationMethods = @{
    Email    = @{
        Enabled    = $false;
        From       = "sender@example.com";
        To         = "recipient@example.com";
        Subject    = "System Alert";
        SmtpServer = "smtp.example.com";
    };
    EventLog = @{
        Enabled  = $true;
        LogName    = "Application";
        Source     = "MadMonitor";
    };
    Popup    = @{
        Enabled  = $true;
    };
    Sound    = @{
        Enabled    = $false;
        SoundPath  = "C:\Windows\Media\Alarm01.wav";
    };
    Script   = @{ # Added Script Notification
        Enabled = $false;
        ScriptPath = "C:\path\to\your\script.ps1"; #path to script
    }
}

# Polling interval (in seconds)
$PollingInterval = 5

#endregion

#region Functions

# Function Definitions
# ------------------
# This section defines the functions used by the script.

# Function to get resource usage
function Get-ResourceUsage {
    param(
        [scriptblock]$Script
    )
    try {
        $usage = Invoke-Command -ScriptBlock $Script -ErrorAction Stop #stop on error
        return $usage
    }
    catch {
        Write-Error "Error getting resource usage: $($_.Exception.Message)"
        return $null
    }
}

# Function to check threshold and trigger alert
function Check-Threshold {
    param(
        [string]$Name,
        [object]$Value,
        [int]$Threshold,
        [string]$AlertType,
        [string]$ComparisonOperator = "GreaterThan" # Default comparison
    )

    $TriggerAlert = $false

    #check if value is null
    if ($Value -eq $null){
        Write-Warning "Value for $($Name) is null, cannot compare"
        return
    }

    #check if value is numeric
    if ($Value -notmatch "^\d+$"){
        Write-Warning "Value for $($Name) is not numeric, cannot compare"
        return
    }

    switch ($ComparisonOperator) {
        "GreaterThan" {
            if ($Value -gt $Threshold) {
                $TriggerAlert = $true
            }
        }
        "LessThan" {
            if ($Value -lt $Threshold) {
                $TriggerAlert = $true
            }
        }
        "Equals" {
            if ($Value -eq $Threshold) {
                $TriggerAlert = $true
            }
        }
        default {
            Write-Warning "Invalid ComparisonOperator.  Defaulting to GreaterThan."
            if ($Value -gt $Threshold) {
                $TriggerAlert = $true
            }
        }
    }

    if ($TriggerAlert) {
        Write-Warning "$Name is above threshold ($Value > $Threshold). Alert triggered."
        Send-Notification -AlertType $AlertType -Value $Value -ResourceName $Name
    }
}

# Function to send notifications
function Send-Notification {
    param(
        [string]$AlertType,
        [object]$Value,
        [string]$ResourceName
    )

    $message = "$AlertType: $ResourceName is at $Value."

    # Send email notification
    if ($NotificationMethods.Email.Enabled) {
        try {
            Send-MailMessage -From $NotificationMethods.Email.From -To $NotificationMethods.Email.To -Subject $NotificationMethods.Email.Subject -Body $message -SmtpServer $NotificationMethods.Email.SmtpServer -ErrorAction Stop
            Write-Verbose "Email sent."
        }
        catch {
            Write-Error "Failed to send email: $($_.Exception.Message)"
        }
    }

    # Write to Event Log
    if ($NotificationMethods.EventLog.Enabled) {
        try {
            Write-EventLog -LogName $NotificationMethods.EventLog.LogName -Source $NotificationMethods.EventLog.Source -EntryType Warning -Message $message -ErrorAction Stop
            Write-Verbose "Event Log entry written."
        }
        catch {
            Write-Error "Failed to write to Event Log: $($_.Exception.Message)"
        }
    }

    # Display a popup
    if ($NotificationMethods.Popup.Enabled) {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            [System.Windows.Forms.MessageBox]::Show($message, "Alert", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
        catch {
            Write-Error "Failed to display popup: $($_.Exception.Message)"
        }
    }

    # Play sound
    if ($NotificationMethods.Sound.Enabled) {
        try {
            [System.Media.SoundPlayer]::PlaySync($NotificationMethods.Sound.SoundPath)
        }
        catch {
            Write-Error "Failed to play sound: $($_.Exception.Message)"
        }
    }

    #run script
    if ($NotificationMethods.Script.Enabled) {
        try {
            $scriptPath = $NotificationMethods.Script.ScriptPath
            if (Test-Path -Path $scriptPath) {
                # Pass the alert details as arguments to the script
                $arguments = @{
                    AlertType    = $AlertType
                    Value        = $Value
                    ResourceName = $ResourceName
                    Message      = $message
                }
                Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"", "-ArgumentList $($arguments | ConvertTo-String)" -Wait
                Write-Verbose "Script executed: $scriptPath"
            }
            else {
                Write-Error "Script not found: $scriptPath"
            }

        }
        catch {
            Write-Error "Failed to execute script: $($_.Exception.Message)"
        }
    }
}

#endregion

#region Main Script

# Main Script Logic
# ----------------
# This section contains the main script logic that runs continuously.

Write-Host "Mad Monitor V2 is starting..."

while ($true) {
    foreach ($resource in $ResourcesToMonitor) {
        if ($resource.Enabled -ne $false) { #check if the resource is enabled.
            $resourceName = $resource.Name
            $resourceValue = Get-ResourceUsage -Script $resource.Script
            $resourceThreshold = $resource.Threshold
            $alertType = $resource.AlertType
            $comparison = $resource.ComparisonOperator # Get the comparison operator

            if ($resourceValue -ne $null) {
                Check-Threshold -Name $resourceName -Value $resourceValue -Threshold $resourceThreshold -AlertType $alertType -ComparisonOperator $comparison
            }
            else {
                Write-Warning "Could not retrieve value for $($resource.Name)"
            }
        }
    }

    Start-Sleep -Seconds $PollingInterval
}

Write-Host "Mad Monitor V2 is stopping..."

#endregion
