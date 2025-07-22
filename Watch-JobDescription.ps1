<#
.SYNOPSIS
    Monitors a folder for newly created .txt files, moves and renames them, and edits lines matching "JobDescription = ..." for formatting consistency.
.DESCRIPTION
    This script creates a FileSystemWatcher event to detect incoming text files in a specified directory.
    Upon detection, it:
      1. Renames the file using the current timestamp
      2. Moves it to a destination folder
      3. Searches for a specific line ("JobDescription = ...")
      4. Modifies the matched line to wrap the value in the appropriate quote format (single, double, or both)
      5. Logs actions and errors to the console and optionally to a log file

.EXAMPLE
    .\Watch-JobDescription.ps1 `
    -folder "C:\watch" `
    -destination "C:\destination" `
    -filter "*.txt" `
    -logpath "C:\logs\filewatcher-log.txt"

.NOTES
    Requires: PowerShell 5+, file access rights to target folders
    Customize the `$folder`, `$destination`, `$filter`, and `$logpath` variables at the top of the script

    DISCLAIMER:
    This script is intended for internal testing, lab environments, or self-directed automation.
    It is provided as-is, with no warranties or guarantees.
    Use with caution in live environments—review all paths, credentials, and host configurations prior to execution.
#>

[CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $folder = "C:\watch",                                                   #Folder to watch
        $destination = "C:\destination",                                        #Folder destination
        $filter = '*.txt',                                                      #Check for this extension
        $logpath = "C:\logs\filewatcher-log.txt"                                #Full path to .txt logfile
    )

#Variables:
$folder = "c:\watch"                        #Folder to watch
$destination = "c:\destination"             #Folder destination
$filter = '*.txt'                           #Check for this extension
$logpath = ""                               #Full path to .txt logfile

#Get Date & Time
$date = (get-date -Format d) -replace("/")  #Get today's date
$time = (get-date -Format t) -replace(":")  #Get today's time

function log{
    #Create logging function that takes $l and $t as inputs
    #$l = Line/whatever must be written to the console/log file
    #$t = Type of information, Error or info
    Param($l, $t)
    if ($t -match "Error"){
        write-host $time -NoNewline
        write-host "    ERROR:  " -f red -NoNewline
        write-host $l -f DarkYellow
        if ($logpath){
            #if $logpath is set, output to log file
            add-content -Value "$time ERROR: $l" -Path $logpath
        }
    }
    else{
        write-host $time -NoNewline
        write-host "    INFO:  " -f cyan -NoNewline
        write-host $l -f Green
        if ($logpath){
            add-content -Value "$time INFO: $l" -Path $logpath
        }
    }
}

try{
    log -l "Creating File System Watcher for $folder" -t "info"
    $fsw = New-Object IO.FileSystemWatcher $folder, $filter                             #Create filesystemwatcher object
    $fsw.IncludeSubdirectories = $false                                                 #Include sub folders?
    $fsw.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'                         #Alert on filename and lastwritetime
}
catch{
    if ($error[0].Exception.InnerException -match "directory|invalid"){                 #If the object creation failed due to invalid foldder, log as error
        log -l "Folder to watch ($folder) does not appear to exist" -t "error"
    }
}

if (! (test-path $destination)){                                                        #if $destination is an invalid folder, then
    try{
        log -l "Destination directory doesn't exist, creating it" -t "Error"            #Log as an error
        New-Item -Path $destination -ItemType Directory | Out-Null                      #Try creating the folder
    }
    catch{
        log -l "Failed to create destination directory" -t "error"                      #Log if folder can't be created
    }
}

Register-ObjectEvent $fsw Created -SourceIdentifier FileCreated -Action {
    #Create the ObjectEvent for watching the folder
    $name = $Event.SourceEventArgs.Name                                                 #Get the file name that is detected
    $changeType = $Event.SourceEventArgs.ChangeType                                     #Get the type of alert (created)

    if ($name -match ".txt"){                                                           #If the file detected is a .txt file
        $folderpath = ($Event.SourceEventArgs.FullPath | Split-Path)                    #Get the full parent folder path
        $folderfile = ($Event.SourceEventArgs.FullPath | Split-Path -Leaf)              #Get the full file name
        $newname = "job.import." + $date + "_" + $time + ".txt"                         #Form new name

        try{
            move-item -Path $event.SourceEventArgs.FullPath -Destination $destination\$newname  #Move the file to destination folder and rename
            log -l "File $folderfile moved to $destination" -t "info"
            log -l "File $folderfile renamed to $newname" -t "info"
        }
        catch{
            log -l "Unable to move file $folderfile" -t "Error"
        }

        try{
            if (test-path ($destination + "\" + $newname)){                             #If the moved & renamed file is in destination folder
                log -l "Opening file to edit" -t "info"
                $getFile = get-content ($destination + "\" + $newname)                  #Retrieve the contents of the file
            }
        }
        catch{
            log -l "Unable to open file for editing" -t "error"
        }

        if ($getFile){                                                                  #If the contents of the file are retrived, then
            foreach ($i in $getFile){                                                   #Iterate through each line of the text file
                if ($i -match[regex] 'JobDescription\s\=\s(.*)'){                       #If the current line matches "JobDescription = "
                    $getLast = ([regex]::Match($i, 'JobDescription\s\=\s(.*)')).Groups[1].Value #Get the last part of the line (after the =)
                    if ($getLast -match[regex] "\'"){                                   #If the last part contains single-quotes, then
                        #Includes single-quote
                        $newLast = $getLast.Replace("'", ('"' + "'"))                   #Replace single-quotes with double + single quotes

                        if ($newLast[0] -ne "'"){                                       #If the first char is in quotes
                            $newLast = "'" + $newLast + "'"                             #Add single-quotes to the beginning and end of part
                        }
                    }
                    elseif ($getLast -match[regex] '\"'){                               #If the last part matches double-quotes
                        #Includes double-quote
                        $newLast = $getLast.Replace('"', ("'" + '"'))                   #Replace double-quotes with single + double quotes
                    }
                    else{
                        #no quotes
                        $newLast = "'" + $getLast + "'"                                 #if no quotes are detected, wrap part in single quotes
                    }

                    $beforeText = ([regex]::Match($i, '^.*\=\s+')).Groups[0].Value      #Get everything before the last part (before =)
                    $newLine = $beforeText + $newLast                                   #Form new line by adding before + new part
                    try{
                        log -l "Saving changes to file" -t "info"
                        $getFile.Replace($i, $newLine) | set-content ($destination + "\" + $newname)    #Try replacing and saving the file
                    }
                    catch{
                        log -l "Unable to save changes to file" -t "error"
                    }
                }
            }
        }
    }
    log -l "Done with this file" -t "info"
}
