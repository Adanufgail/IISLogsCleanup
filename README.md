# IISLogsCleanup.ps1 - A PowerShell script to delete IIS log files.

This script will check the folder that you specify, and any files older than the 7 days will be deleted.

## Parameters

* **-Logpath**, The IIS log directory to cleanup.

## Usage Examples

```
.\IISLogsCleanup.ps1 -Logpath "D:\IIS Logs\W3SVC1"
```
This example will find the log files in "D:\IIS Logs\W3SVC1" and delete them.

## Original Credits

Written by: Paul Cunningham

* Github:	https://github.com/cunninghamp
