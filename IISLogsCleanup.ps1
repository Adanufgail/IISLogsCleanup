<#
.SYNOPSIS
IISLogsCleanup.ps1 - IIS Log File Cleanup Script

.DESCRIPTION 
A PowerShell script to compress and archive IIS log files.

This script will check the folder that you specify, and any files older
than the first day of the previous month will be compressed into a
zip file. If you specify an archive path as well the zip file will be
moved to that location.

The recommended use for this script is a once-monthly scheduled task
run on the first day of each month. This will compress all files older
than the first day of the previous month, resulting in only 1-2 months
of log files being stored on the server.

If the script detects any issues with the archive process that may
indicate that a file was missed it will not delete the log files from
the folder.

The script also writes a log file each time it is run so you can check
the results or troubleshoot any issues.

.PARAMETER Logpath
The IIS log directory to cleanup.

.PARAMETER ArchivePath
The path to a location where zip files are moved to, for example
a central log repository stored on a NAS.

.EXAMPLE
.\IISLogsCleanup.ps1 -Logpath "D:\IIS Logs\W3SVC1"
This example will compress the log files in "D:\IIS Logs\W3SVC1" and leave
the zip files in that location.

.EXAMPLE
.\IISLogsCleanup.ps1 -Logpath "D:\IIS Logs\W3SVC1" -ArchivePath "\\nas01\archives\iislogs"
This example will compress the log files in "D:\IIS Logs\W3SVC1" and move
the zip files to the archive path.

.LINK
http://exchangeserverpro.com/powershell-script-iis-logs-cleanup

.NOTES
Written by: Paul Cunningham

Find me on:

* My Blog:	https://paulcunningham.me
* Twitter:	https://twitter.com/paulcunningham
* LinkedIn:	https://au.linkedin.com/in/cunninghamp/
* Github:	https://github.com/cunninghamp

Additional Credits:
Filip Kasaj - http://ficility.net/2013/02/25/ps-2-0-remove-and-compress-iis-logs-automatically/
Rob Pettigrew - regional date issues
Alain Arnould - Zip file locking issues

License:

The MIT License (MIT)

Copyright (c) 2015 Paul Cunningham

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Change Log
V1.00, 7/04/2014, Initial version
V1.01, 8/08/2015, Fix for regional date format issues, Zip file locking issues.
V1.02, 25/08/2015, Fixed typo in a variable
#>


[CmdletBinding()]
param (
	[Parameter( Mandatory=$true)]
	[string]$Logpath,

    [Parameter( Mandatory=$false)]
    [string]$ArchivePath
	)


#-------------------------------------------------
#  Variables
#-------------------------------------------------

$sleepinterval = 5

$computername = $env:computername

$now = Get-Date
$currentmonth = ($now).Month
$currentyear = ($now).Year
$previousmonth = ((Get-Date).AddMonths(0)).Month
$firstdayofpreviousmonth = (Get-Date -Year $currentyear -Month $currentmonth -Day 1).AddMonths(0)
$firstdayofpreviousmonth = (Get-Date).AddDays(-7)

$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$output = "$myDir\IISLogsCleanup.log"
$logpathfoldername = $logpath.Split("\")[-1]

#...................................
# Logfile Strings
#...................................

$logstring0 = "====================================="
$logstring1 = " IIS Log File Cleanup Script"


#-------------------------------------------------
#  Functions
#-------------------------------------------------

#This function is used to write the log file for the script
Function Write-Logfile()
{
	param( $logentry )
	$timestamp = Get-Date -DisplayHint Time
	"$timestamp $logentry" | Out-File $output -Append
}

# This function is to test the completion of the async CopyHere method
# Function provided by Alain Arnould
function IsFileLocked( [string]$path)
{
    If ([string]::IsNullOrEmpty($path) -eq $true) {
        Throw “The path must be specified.”
    }

    [bool] $fileExists = Test-Path $path

    If ($fileExists -eq $false) {
        Throw “File does not exist (” + $path + “)”
    }

    [bool] $isFileLocked = $true

    $file = $null

    Try
    {
        $file = [IO.File]::Open($path,
                        [IO.FileMode]::Open,
                        [IO.FileAccess]::Read,
                        [IO.FileShare]::None)

        $isFileLocked = $false
    }
    Catch [IO.IOException]
    {
        If ($_.Exception.Message.EndsWith(“it is being used by another process.”) -eq $false)
        {
            # Throw $_.Exception
            [bool] $isFileLocked = $true
        }
    }
    Finally
    {
        If ($file -ne $null)
        {
            $file.Close()
        }
    }

    return $isFileLocked
}


#-------------------------------------------------
#  Script
#-------------------------------------------------

#Log file is overwritten each time the script is run to avoid
#very large log files from growing over time

$timestamp = Get-Date -DisplayHint Time
"$timestamp $logstring0" | Out-File $output
Write-Logfile $logstring1
Write-Logfile "  $now"
Write-Logfile $logstring0w


#Check whether IIS Logs path exists, exit if it does not
if ((Test-Path $Logpath) -ne $true)
{
    $tmpstring = "Log path $logpath not found"
    Write-Warning $tmpstring
    Write-Logfile $tmpstring
    EXIT
}


$tmpstring = "Current Month: $currentmonth"
Write-Host $tmpstring
Write-Logfile $tmpstring

$tmpstring = "Previous Month: $previousmonth"
Write-Host $tmpstring
Write-Logfile $tmpstring

$tmpstring = "First Day of Previous Month: $firstdayofpreviousmonth"
Write-Host $tmpstring
Write-Logfile $tmpstring

#Fetch list of log files older than 1st day of previous month
$logstoremove = Get-ChildItem -Path "$($Logpath)\*.*" -Include *.log | Where {$_.CreationTime -lt $firstdayofpreviousmonth -and $_.PSIsContainer -eq $false}

if ($($logstoremove.Count) -eq $null)
{
    $logcount = 0
}
else
{
    $logcount = $($logstoremove.Count)
}

$tmpstring = "Found $logcount logs earlier than $firstdayofpreviousmonth"
Write-Host $tmpstring
Write-Logfile $tmpstring

#Init a hashtable to store list of log files
$hashtable = @{}

#Add each logfile to hashtable
foreach ($logfile in $logstoremove)
{
    $zipdate = $logfile.LastWriteTime.ToString("yyyy-MM")
    $hashtable.Add($($logfile.FullName),"$zipdate")
}

#Calculate unique yyyy-MM dates from logfiles in hashtable
$hashtable = $hashtable.GetEnumerator() | Sort Value
$dates = @($hashtable | Group -Property:Value | Select Name)

#For each yyyy-MM date add those logfiles to a zip file
foreach ($date in $dates)
{
    $zipfiles = $hashtable | Where {$_.Value -eq "$($date.Name)"}

    foreach($file in $zipfiles) 
    { 
        $fn = $file.key.ToString()
        Remove-Item $fn
    }
}


#Finished
$tmpstring = "Finished"
Write-Host $tmpstring
Write-Logfile $tmpstring


#...................................
# Finished
#...................................
