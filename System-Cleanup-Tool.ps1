<#
.DISCLAIMER
    ⚠️ This script is aggressive and destructive by design.

    - It deletes all Windows Event Logs.
    - It removes files from system and user temp folders, caches, and recycle bins.
    - It targets Office 2016-specific paths and may not be compatible with other versions.
    - It is not intended for use in production environments without thorough review and testing.

    Use at your own risk. Always test in a controlled environment before applying to live systems.

.SYNOPSIS
    Performs a comprehensive cleanup of temporary files, caches, logs, and other system clutter across Windows environments.

.DESCRIPTION
    This script performs the following operations:
        1. Logs disk space usage before and after cleanup.
        2. Deletes ISO and VHD files from user profiles.
        3. Clears Office 2016 cache directories (WebServiceCache, FileCache, MRU, Navigation).
        4. Removes Windows Error Reporting (WER) data.
        5. Empties all user and system recycle bins.
        6. Clears Windows Prefetch data.
        7. Deletes all Windows Event Logs.
        8. Stops the Windows Update service and purges SoftwareDistribution contents.
        9. Cleans Windows Temp, user Temp, and Temporary Internet Files.
       10. Deletes IIS logs older than 60 days (if present).
       11. Logs disk usage and file size summaries for ticketing or audit purposes.

.REQUIREMENTS
    - PowerShell 5.1
    - Local administrator privileges
    - Office 2016-specific cache paths (may need adjustment for other versions)

.NOTES
    Tested on: Windows 10 / Windows Server 2016  
    Useful for post-deployment cleanup, system prep, or freeing up disk space before imaging.

    Variable guidance:
    - $DaysToDelete: Files older than this number of days will be deleted (default: 365).
    - $VerbosePreference: Controls whether verbose output is shown (default: "Continue").
#>

Function Cleanup {

function global:Write-Verbose ( [string]$Message )

# check $VerbosePreference variable, and turns -Verbose on
{ if ( $VerbosePreference -ne 'SilentlyContinue' ){ 
    Write-Host " $Message" -ForegroundColor 'Yellow' 
    }}

$VerbosePreference = "Continue"
$DaysToDelete = 365
$LogDate = get-date -format "MM-d-yy-HH"
$objShell = New-Object -ComObject Shell.Application 
$objFolder = $objShell.Namespace(0xA)
$ErrorActionPreference = "silentlycontinue"
                    
Start-Transcript -Path C:\Windows\Temp\$LogDate.log

## Cleans all code off of the screen.
Clear-Host

$size = Get-ChildItem C:\Users\* -Include *.iso, *.vhd -Recurse -ErrorAction SilentlyContinue | 
Sort Length -Descending | 
Select-Object Name, Directory,
@{Name="Size (GB)";Expression={ "{0:N2}" -f ($_.Length / 1GB) }} |
Format-Table -AutoSize | Out-String

$Before = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
@{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
@{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
@{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } },
@{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } |
Format-Table -AutoSize | Out-String    

## Cleans Office cache paths
$office_webservices_cache = "C:\Users\*\AppData\Local\Microsoft\Office\16.0\WebServiceCache\AllUsers"
$office_filecache = "C:\Users\*\AppData\Local\Microsoft\Office\16.0\OfficeFileCache\*"
$office_mrucache = "C:\Users\*\AppData\Local\Microsoft\Office\16.0\MruServiceCache\*"
$office_navcache = "C:\Users\*\AppData\Local\Microsoft\Office\16.0\BackstageInAppNavCache\*"

#Clear office web cache
$get_webservices_cache = Get-ChildItem $office_webservices_cache -Recurse
if ($get_webservices_cache.count -gt 0){
    Get-ChildItem $office_webservices_cache | Remove-Item -Recurse -Force
}
#Clear office file cache (Main cache files)
$get_filecache = Get-ChildItem $office_filecache -Recurse
if ($get_filecache.count -gt 0){
    Get-ChildItem $office_filecache | Remove-Item -Recurse -Force
}
#Clear office MRU cache
$get_mrucache = Get-ChildItem $office_mrucache -Recurse
if ($get_mrucache.count -gt 0){
    Get-ChildItem $office_mrucache | Remove-Item -Recurse -Force
}
#Clear office navigation cache
$get_navcache = Get-ChildItem $office_navcache -Recurse
if ($get_get_navcache.count -gt 0){
    Get-ChildItem $office_navcache | Remove-Item -Recurse -Force
}
## Office cache paths cleaned

## Clear Windows Error Reporting
$get_wer = get-childitem "C:\Users\*\AppData\Local\Microsoft\Windows\WER\*" -Recurse
if ($get_wer.count -gt 0){
    Remove-Item -path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\*" -Recurse -Force
}
## WER cleared

## Clear recycle bins
$Shell = New-Object -ComObject Shell.Application
$RecycleBin = $Shell.Namespace(0xA)
$RecycleBin.Items() | foreach{Remove-Item $_.Path -Recurse -Force} 
## Recycle bins cleared

## Clear Windows prefetch data
$get_prefetch = Get-ChildItem "c:\Windows\Prefetch\*" -Recurse
if ($get_prefetch.count -gt 0){
    remove-item $win_pref_path -Recurse -Force
}
## Windows prefetch data cleared

## Clear Event Logs  !Deletes all event logs!
Get-EventLog -LogName * | ForEach { Clear-EventLog $_.Log }
## Event logs cleared

## Stops the windows update service. 
Get-Service -Name wuauserv | Stop-Service -Force -Verbose -ErrorAction SilentlyContinue
## Windows Update Service has been stopped successfully!

## Deletes the contents of windows software distribution.
Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete)) } |
remove-item -force -Verbose -recurse -ErrorAction SilentlyContinue
## The Contents of Windows SoftwareDistribution have been removed successfully!

## Deletes the contents of the Windows Temp folder.
Get-ChildItem "C:\Windows\Temp\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete)) } |
remove-item -force -Verbose -recurse -ErrorAction SilentlyContinue
## The Contents of Windows Temp have been removed successfully!
             
## Deletes all files and folders in user's Temp folder. 
Get-ChildItem "C:\users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete))} |
remove-item -force -Verbose -recurse -ErrorAction SilentlyContinue
## The contents of C:\users\$env:USERNAME\AppData\Local\Temp\ have been removed successfully!
                    
## Remove all files and folders in user's Temporary Internet Files. 
Get-ChildItem "C:\users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" `
-Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} |
remove-item -force -recurse -ErrorAction SilentlyContinue
## All Temporary Internet Files have been removed successfully!
                    
## Cleans IIS Logs if applicable.
Get-ChildItem "C:\inetpub\logs\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -le $(Get-Date).AddDays(-60)) } |
Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue
## All IIS Logfiles over x days old have been removed Successfully!
                  
## deletes the contents of the recycling Bin.
## The Recycling Bin is now being emptied!
$objFolder.items() | ForEach-Object { Remove-Item $_.path -ErrorAction Ignore -Force -Verbose -Recurse }
## The Recycling Bin has been emptied!

## Starts the Windows Update Service
##Get-Service -Name wuauserv | Start-Service -Verbose

$After =  Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
@{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
@{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
@{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } },
@{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } |
Format-Table -AutoSize | Out-String

## Sends some before and after info for ticketing purposes

Hostname ; Get-Date | Select-Object DateTime
Write-Verbose "Before: $Before"
Write-Verbose "After: $After"
Write-Verbose $size
## Completed Successfully!
Stop-Transcript } Cleanup

