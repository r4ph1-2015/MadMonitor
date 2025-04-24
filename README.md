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

Release Notes :
V1 - Added A Second Window for Network Data Viewing , Added New Features , Fixed Some Bugs.
