<#
.SYNOPSIS
    Monitors a specified folder for files older than a given number of minutes and sends an email alert if any are found.
.DESCRIPTION
    This PowerShell script scans a target directory for files matching a specific extension or filename pattern.
    If any matching files are older than the threshold defined by `$minutesOld`, it compiles a list and sends an alert via email.

    PROCESS:
        1. Scan the folder for files matching the specified extension(s) or filename pattern.
        2. Identify files older than the specified number of minutes based on LastWriteTime.
        3. Build a report listing the old files found and their age criteria.
        4. Send the report to a configured email recipient using SMTP authentication.

    VARIABLES:
        - `$minutesOld`      : Number of minutes after which a file is considered "old".
        - `$folder`          : Full path of the folder to monitor.
        - `$searchType`      : Set to `"pattern"` to enable filename pattern matching via `$searchPattern`; leave blank to use extension filtering only.
        - `$searchPattern`   : If enabled, defines the pattern (e.g., "*_*.csv") for file filtering.
        - `$fileType`        : Pipe-separated list of allowed file extensions (e.g., `"csv|xml"`).
        - `$mailUser`/`$mailPass` : SMTP credentials used to send the email alert.
        - `$mailTo`          : Recipient of the alert email.

.NOTES
    PowerShell version: 5.x or later recommended
    Requires access to an SMTP server for email notification.
    Ensure sensitive data (like passwords) are stored securely and not committed to public repositories.

    DISCLAIMER:
    This script is intended for internal testing, lab environments, or self-directed automation.
    It is provided as-is, with no warranties or guarantees.
    Use with caution in live environments—review all paths, credentials, and host configurations prior to execution.
#>

#Monitor Settings:
$minutesOld = "60"                                          #After this x number of minutes, file will be considered old
$folder = "C:\myfolder"                                     #Full path of folder to monitor
$searchType = "pattern"                                     #Set to "pattern" or leave blank. Setting to "pattern" will enable $searchPattern
$searchPattern = '*_*'                                      #Pattern matching the files you're filtering for
$fileType = "csv|xml"                                       #Extensions of the files you're looking for

#SMTP Settings:
$mailUser = "email@domain.com"                              #SMTP mail account username
$mailPass = "REPLACE_WITH_PASSWORD"                         #SMTP mail account password
$mailServer = "mail.domain.com"                             #SMTP mail server hostname or address
$mailPort = "25"                                            #SMTP port your mail server uses
$mailSubject = "Old File Detection"                         #Subject for the alert email
$mailTo = "admin@company.com"                               #Recipient of alert email

#Start of script

if ($searchType -match "pattern"){                          #If $searchType is "pattern" - Get all files matching that pattern + the extensions listed in $fileType
    $get = Get-ChildItem -Path $folder | where {$_.name -like $searchPattern -and $_.Extension -match $fileType}
}
else{
    $get = Get-ChildItem -Path $folder | where {$_.Extension -match $fileType}  #If $searchType is blank. Only get files matching extensions listed in $fileType
}

try{
    $oldFiles = @()                                                                         #Create empty array for storing file names
    $filter = $get | where {$_.LastWriteTime -lt ((get-date).AddMinutes(-$minutesOld))}     #Filter all file results into 'old' files matching the time elapsed $minutesOld
    if ($filter){                                                                           #If the old files exist, then:
        write-host "Found $($filter.count) old files" -f DarkYellow
        $oldFiles += $filter | select -expand name                                          #Add all old files into $oldFiles array
    }
}
catch{
    write-host "Failed to retrieve filtered file list" -f Red
    exit                                                                                    #Exit if there was a problem getting the old files
}

<#
Set email body:
    - Folder being monitored
    - Show list of all old files detected
    - Age filter parameter of the script
#>

$body = @"                 
    Hello,

    There appears to be an old file or old files in the monitored folder:

    Monitored Directory     : $($folder)
    $(if ($oldFiles.count -eq 1){
    "Old Files               : $($oldFiles[0])"
    })
    $(if ($oldFiles.count -gt 1){
    "Old Files               : $($oldFiles[0])$($oldFiles[1..$oldFiles.Count] | foreach {"`n                              $_"}) `n"
    })
    Age of Files            : Older than $($minutesold) minutes
"@

#Create SMTP mail credentials object
$SMTPpass = $mailPass | ConvertTo-SecureString -AsPlainText -Force
$creds = new-object -typename System.Management.Automation.PSCredential -argumentlist $mailUser,$SMTPpass

if ($oldFiles.count -gt 0){
    write-host "Sent email" -f Green
    #Send email
    Send-MailMessage -body $body -SmtpServer $mailServer -from $mailUser -To $mailTo -Subject $mailSubject -Credential $creds
}
