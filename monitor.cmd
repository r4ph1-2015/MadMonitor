@echo off
cd /d "C:\Users\(User)\MonitorPS"
start "" powershell.exe -NoExit -ExecutionPolicy Bypass -File ".\Monitor.ps1" -CSVLogging -HighCPUThreshold 85 -HighMemoryThreshold 85 -LowHealthThreshold 65
start "" powershell.exe -NoExit -ExecutionPolicy Bypass -File ".\Network.ps1"
exit
