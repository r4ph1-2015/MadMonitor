# MadMonitor
MadMonitor is a Monitor for Both your System and Your Network

It uses Powershell, Here is a Guide How to setup and use it

1.Go in Command Prompt
2.Enter Powershell
3.To get rich desktop notifications, you'll need to install the BurntToast PowerShell module. Here's the command you can use:

Install-Module BurntToast -Scope CurrentUser

This command installs the module for the current user. If you want to install it for all users, you'll need to run PowerShell as an administrator and use this command:

Install-Module BurntToast -Scope AllUsers

After the installation, the Show-Notification function in the script should be able to display rich desktop notifications.
4.Edit Monitor.cmd
5.Go to Line 2 
6.Change the Directory to your Specific Directory Location 
7.Use Win+R and Enter (The Location of the Monitor.cmd file)\Monitor.cmd
8.You will get two cmd windows running Powershell with MadMonitor
9.You can look at the Data shown by Mad Monitor

V2 Instructions:
Mad Monitor V2 User Instructions
I. Introduction
Mad Monitor V2 is a PowerShell script designed to monitor system resources on Windows computers and alert administrators to potential issues. It provides a flexible and customizable way to track key performance indicators and receive timely notifications when thresholds are exceeded. This version enhances the original Mad Monitor with improved error handling, more versatile alerting, and easier configuration.
Key Features:
 * Customizable Resource Monitoring: Monitor a wide range of system resources, including CPU usage, memory usage, disk space, and battery level.
 * Flexible Alert Thresholds: Define alert thresholds using PowerShell expressions, including greater than, less than, and equal to comparisons.
 * Multiple Notification Methods: Receive alerts via email, Windows Event Log, pop-up notifications, sound, or custom PowerShell scripts.
 * Robust Error Handling and Logging: Improved error handling and logging to ensure script stability and facilitate troubleshooting.
 * Easy Configuration via PowerShell: Configure monitoring settings and alert behavior directly within the script using PowerShell variables.
System Requirements:
 * Operating System: Windows 10, Windows Server 2016 or later
 * PowerShell: PowerShell 5.1 or later
II. Installation
Prerequisites:
 * Ensure your system meets the operating system and PowerShell version requirements.
 * To check your PowerShell version, open a PowerShell console and type:
   $PSVersionTable.PSVersion

Installation Steps:
 * Download the Script: Download the Monitor.ps1 script.
 * Save the Script: Save the Monitor.ps1 script to a location on your computer (e.g., C:\Scripts\Monitor.ps1).
 * Set Execution Policy (Important): PowerShell's execution policy restricts which scripts can be run. To allow Mad Monitor V2 to run, you may need to adjust the execution policy.
   * Caution: Setting the execution policy too permissively can pose a security risk. It's crucial to choose the most restrictive policy that allows the script to function.
   * Recommended Policy: RemoteSigned is generally a good balance between security and usability. This policy allows you to run scripts that you download from the internet, as long as they are signed by a trusted publisher.
   * To set the execution policy to RemoteSigned, open a PowerShell console as an administrator and type:
     Set-ExecutionPolicy RemoteSigned

   * Security Best Practice: If you have signed the Monitor.ps1 script with your own code signing certificate, you can use a more restrictive policy, such as AllSigned.
Testing the Installation:
 * Open a PowerShell console.
 * Navigate to the directory where you saved the Monitor.ps1 script (e.g., cd C:\Scripts).
 * Run the script with a minimal configuration to test if it's working:
   .\Monitor.ps1

 * You should see the message "Mad Monitor V2 is starting...".  If the script encounters an error it will display it in the console.
III. Configuration
Mad Monitor V2 is configured by modifying the variables in the #region Configuration section of the Monitor.ps1 script. You will need to edit the script using a text editor (e.g., Notepad, PowerShell ISE, Visual Studio Code) to customize it to your environment.
Detailed Configuration Options:
 * $ResourcesToMonitor: This variable defines the system resources that Mad Monitor V2 will monitor. It is an array of hash tables, where each hash table represents a resource.
   * Name (String): A descriptive name for the resource (e.g., "CPU Usage", "Memory Usage", "Disk Space (C:)").  This name will be used in alerts.
   * Script (ScriptBlock): A PowerShell script block that retrieves the value of the resource.  The script block should return a single value.
   * Threshold (Integer/String): The threshold value for the resource.  When the resource value exceeds (or falls below, depending on the ComparisonOperator) this threshold, an alert is triggered.  For most resources, this will be an Integer.  For service status, this will be a String (e.g., "Running", "Stopped").
   * AlertType (String): A descriptive text for the alert (e.g., "High CPU Usage", "Low Memory", "Disk Space Low").  This text will be included in notifications.
   * ComparisonOperator (String): Specifies how the resource value is compared to the threshold.  Valid values are:
     * "GreaterThan" (Default): Triggers an alert if the resource value is greater than the threshold.
     * "LessThan": Triggers an alert if the resource value is less than the threshold.
     * "Equals": Triggers an alert if the resource value is equal to the threshold.
   * Enabled (Boolean): A flag to enable or disable monitoring for this resource.  Set to $true to enable (default), $false to disable.
   Examples:
   $ResourcesToMonitor = @(
    @{
        Name              = "CPU Usage";
        Script            = { Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 5 -MaxSamples 1 | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue };
        Threshold         = 80;    # Percentage
        AlertType         = "High CPU Usage";
        ComparisonOperator = "GreaterThan"; # (Default)
        Enabled           = $true;
    },
    @{
        Name              = "Free Disk Space (C:)";
        Script            = { (Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Root -eq "C:"}).FreeSpace / 1GB };
        Threshold         = 10;    # GB
        AlertType         = "Low Disk Space";
        ComparisonOperator = "LessThan";
        Enabled           = $true;
    },
    @{
        Name              = "Service Status (Spooler)";
        Script            = { (Get-Service -Name Spooler).Status };
        Threshold         = "Running";
        AlertType         = "Spooler Service Stopped";
        ComparisonOperator = "Equals";
        Enabled           = $true;
    },
    @{
        Name              = "Battery Level";
        Script            = {
            $batteryInfo = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
            if ($batteryInfo) {
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
        Enabled           = $true; #you can disable this if needed
    }
)

 * $NotificationMethods: This variable defines how Mad Monitor V2 sends alerts. It is a hash table where each key represents a notification method.
   * Email: Sends alerts via email.
     * Enabled (Boolean): Set to $true to enable email notifications, $false to disable.
     * From (String): The email address to send alerts from.
     * To (String): The email address to send alerts to.
     * Subject (String): The subject of the email.
     * SmtpServer (String): The address of the SMTP server.
   * EventLog: Writes alerts to the Windows Event Log.
     * Enabled (Boolean): Set to $true to enable Event Log notifications, $false to disable.
     * LogName (String): The name of the Event Log to write to (e.g., "Application", "System").
     * Source (String): The source name for the Event Log entries (e.g., "MadMonitorV2").
   * Popup: Displays a pop-up message on the screen.
     * Enabled (Boolean): Set to $true to enable pop-up notifications, $false to disable.
   * Sound: Plays a sound.
     * Enabled (Boolean): Set to $true to enable sound notifications, $false to disable.
     * SoundPath (String): The path to the sound file (e.g., "C:\Windows\Media\Alarm01.wav").
   * Script: Executes a PowerShell script.
     * Enabled (Boolean): Set to $true to enable script execution, $false to disable.
     * ScriptPath (String): The path to the PowerShell script to execute. The script will receive the following arguments:  AlertType, Value, ResourceName, and Message.
   Examples:
   $NotificationMethods = @{
    Email    = @{
        Enabled    = $false;
        From       = "madmonitor@example.com";
        To         = "admin@example.com";
        Subject    = "System Alert from Mad Monitor V2";
        SmtpServer = "smtp.example.com";
    };
    EventLog = @{
        Enabled  = $true;
        LogName    = "Application";
        Source     = "MadMonitorV2";
    };
    Popup    = @{
        Enabled  = $false;
    };
    Script   = @{
        Enabled = $false;
        ScriptPath = "C:\scripts\alert_action.ps1"
    }
)

 * $PollingInterval: This variable defines how often (in seconds) Mad Monitor V2 checks the system resources.  A lower value means more frequent checks, but also higher resource usage by the script itself.  A higher value means less frequent checks, but potential delays in detecting issues.
   * Example:
     $PollingInterval = 60 # Check every 60 seconds

Best Practices:
 * Back Up the Script: Before making any changes to the Monitor.ps1 script, create a backup copy to prevent data loss.
 * Test Your Configuration: After modifying the script, test it thoroughly to ensure that it's working as expected.  Start with a low threshold for a resource to trigger a test alert and verify that the notification is sent correctly.
 * Set Appropriate Thresholds: Carefully choose threshold values that are appropriate for your system and environment.  Setting thresholds too low can result in excessive alerts, while setting them too high can cause you to miss important issues.
IV. Usage
Running the Script:
 * Open a PowerShell console.
 * Navigate to the directory where you saved the Monitor.ps1 script.
 * Run the script:
   .\Monitor.ps1

   The script will start monitoring the resources and display the message "Mad Monitor V2 is starting...".  It will continue to run until you close the PowerShell console.
Running as a Scheduled Task:
To run Mad Monitor V2 automatically, you can create a scheduled task:
 * Open PowerShell as an administrator.
 * Use the Register-ScheduledTask cmdlet to create a new task.  Here's an example:
   $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Monitor.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 00:00 # Run daily at midnight
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "MadMonitorV2" -Action $action -Trigger $trigger -Principal $principal

   * Explanation:
     * $action: Defines the action to perform (run PowerShell and execute the script).
     * $trigger: Defines when to run the task (daily at midnight in this example).  You can customize this to run at different intervals (e.g., hourly, every 5 minutes).
     * $principal: Defines the user account to run the task as.  "NT AUTHORITY\SYSTEM" has high privileges.
     * Register-ScheduledTask: Creates the scheduled task.
   * Important Notes:
     * Adjust the -File parameter to the actual path of your Monitor.ps1 script.
     * Choose an appropriate trigger for your needs.
     * Running the task as SYSTEM provides the necessary permissions to monitor most system resources, but be aware of the security implications.  If possible, create a dedicated user account with the minimum required privileges.
     * The -NoProfile parameter prevents PowerShell from loading your profile, ensuring a clean execution environment for the script.
     * The -ExecutionPolicy Bypass parameter might be needed if your script is not signed.  Use with caution and understand the security implications.
Monitoring the Script:
 * Event Log: Mad Monitor V2 logs events to the Windows Event Log (if the EventLog notification method is enabled).  Check the Application log for entries with the source "MadMonitorV2" to see when alerts are triggered.
 * Script Output: When the script is running in a PowerShell console, it will display messages indicating when it starts, stops, and when alerts are triggered.
V. Customization
Adding Custom Scripts:
You can extend Mad Monitor V2's functionality by adding your own PowerShell scripts to monitor specific resources or perform custom actions when alerts are triggered.
 * To add a custom resource to monitor:
   * Write a PowerShell script block that retrieves the value of the resource.  The script block should return a single value.
   * Add a new entry to the $ResourcesToMonitor array with the following properties:
     * Name: A descriptive name for your custom resource.
     * Script: The script block you created.
     * Threshold: The threshold value.
     * AlertType: A descriptive alert type.
     * ComparisonOperator: (Optional)
     * Enabled: (Optional)
 * To add a custom action when an alert is triggered:
   * Write a PowerShell script that performs the desired action.  This script will receive the following arguments:
     * $AlertType: The type of alert.
     * $Value: The value of the resource that triggered the alert.
     * $ResourceName: The name of the resource.
     * $Message: The full alert message.
   * Set the ScriptPath property in the $NotificationMethods.Script section to the path of your script, and set Enabled to $true.
Example (Custom Resource - Process Count):
$ResourcesToMonitor = @(
    # ... (other resources)
    @{
        Name              = "Process Count (notepad++)";
        Script            = { (Get-Process -Name "notepad++" -ErrorAction SilentlyContinue).Count };
        Threshold         = 2;    # Alert if more than 2 instances are running
        AlertType         = "Too Many Notepad++ Instances";
        ComparisonOperator = "GreaterThan";
        Enabled           = $true;
    }
)

Example (Custom Action Script - C:\scripts\alert_action.ps1):
param(
    [string]$AlertType,
    [object]$Value,
    [string]$ResourceName,
    [string]$Message
)

# This script will be executed when an alert is triggered.

Write-Host "Custom Action Triggered!"
Write-Host "Alert Type:    $AlertType"
Write-Host "Resource Name: $ResourceName"
Write-Host "Value:         $Value"
Write-Host "Message:       $Message"

# Add your custom actions here (e.g., restart a service, log to a database, send a message to a chat room).
# Example: Restart a service
# if ($AlertType -eq "Service Stopped") {
#     Start-Service -Name $ResourceName
#     Write-Host "Restarted service: $ResourceName"
# }

VI. Troubleshooting
Common Issues:
 * Script Not Running:
   * Ensure that the PowerShell execution policy is set correctly.
   * Verify that the Monitor.ps1 script is saved in the correct location and that you are running it from the correct directory.
 * Errors Related to Permissions:
   * If you are monitoring system resources that require administrative privileges, ensure that you are running the script or the scheduled task as an administrator.
 * Problems with Notification Methods:
   * Email: Verify that your email settings (sender address, recipient address, SMTP server) are correct.  Check your SMTP server settings.
   * Event Log: Ensure that the script has permissions to write to the specified Event Log.
   * Popup: Ensure that the System.Windows.Forms assembly can be loaded.
   * Sound: Verify that the specified sound file exists and is in a supported format.
   * Script: Ensure that the ScriptPath is correct, the script has the necessary permissions, and it executes without errors.
 * No Alerts Received:
   * Double-check that the $ResourcesToMonitor and $NotificationMethods variables are configured correctly.
   * Verify that the resource values are actually exceeding the thresholds.
   * Temporarily set a very low threshold to trigger a test alert.
   * Check the Event Log for any errors related to the script.
Error Messages:
Mad Monitor V2 provides detailed error messages to help you diagnose problems.  Pay close attention to the error messages displayed in the PowerShell console or logged to the Event Log.  These messages will often indicate the cause of the problem and provide clues on how to resolve it.
Logging:
Mad Monitor V2 uses the Windows Event Log (if enabled) to log events, including errors and alerts.  Check the Application log for entries with the source "MadMonitorV2" to find information about the script's activity.
Getting Help:
If you encounter problems or have questions about Mad Monitor V2, please contact Support@madmonitor.aleeas.com for assistance.  You can also find more information and updates on the Mad Monitor Repository made by R4PH1_2015
X. License
Mad Monitor V2 is distributed under the Apache License. See the LICENSE file for more information.

Release Notes :
V1 - Added A Second Window for Network Data Viewing , Added New Features , Fixed Some Bugs.
