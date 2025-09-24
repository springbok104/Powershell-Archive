<#
.SYNOPSIS
    Converts a structured JSON file into a flat CSV format, including UNIX timestamp conversion.

.DESCRIPTION
    This script performs the following operations:
        1. Imports a raw JSON file containing a header row and a list of records.
        2. Converts UNIX timestamps (seconds + milliseconds) into human-readable date and time.
        3. Iterates through each record's measurements and maps them to corresponding headers.
        4. Outputs the transformed data to a CSV file.

    Sample JSON structure:
        {
            "Header_Row": ["seconds", "ms", "tz", "Temperature", "Humidity"],
            "Records": [
                {
                    "seconds": 1719830400,
                    "ms": 123,
                    "Measurements": [22.5, 55.1]
                },
                ...
            ]
        }

    Sample CSV output:
        Date,Time,TZ Offset,Temperature,Humidity
        2024-07-01,14:23:45.1230000Z,0,22.5,55.1

.REQUIREMENTS
    - PowerShell 5.1
    - JSON file must follow the expected structure with "Header_Row" and "Records" arrays

.NOTES
    Useful for transforming time-series sensor or telemetry data into a flat, analyzable format.

    Variables:
    - $import: Full path to the input JSON file.
    - $export: Full path to the output CSV file.
#>


#Path variables:
$import = ".\jsonfile.json"                                                     #Path to JSON file
$export = ".\output.csv"                                                        #Export path to CSV

#Initialise variables:
$Global:Date = $null
$Global:Time = $null
$out_obj = @()
$dataobj = @()

#Function:
function Convert-UNIX {                                                             #Function to convert UNIX timestamp into DateTime object
    Param($unix, $ms)                                                               #Takes timestamp and MS as inputs
    $start_epoch = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0   #Starts DateTime object from beginning of UNIX epoch
    $add_minutes = $start_epoch.AddSeconds($unix)                                   #Adds the minutes from the timestamp
    $full_time = $add_minutes.AddMilliseconds($ms)                                  #Adds the MS to the object
    $global:date = ($full_time | get-date -format s).Split('T')[0]                  #Grabs the Date from the string, and puts this in a variable
    $global:time = ($full_time | get-date -format o).Split('T')[-1]                 #Grabs the Time from the string and puts this in a variable
}

if (test-path $import){
    try{
    $json = get-content $import | ConvertFrom-Json                                  #Get JSON raw content and convert to JSON format
    $headers_adj = $json.Header_Row[3..$json.Header_Row.count]                      #Get all headers, except for first 3

    foreach ($s in $json.Records){                                                      #For each record file:
        Convert-UNIX -unix $s.seconds -ms $s.ms                                             #Convert unix time stamp into HR formats for date, time
        $dataobj = New-Object psobject      
        $dataobj | Add-Member -MemberType NoteProperty -Name "Date" -Value $Global:Date     #Create object, and input Date, Time, and TZ Offset
        $dataobj | Add-Member -MemberType NoteProperty -Name "Time" -Value $Global:Time
        $dataobj | Add-Member -MemberType NoteProperty -Name "TZ Offset" -Value "0"
        
        $count = -1                                                                         #Set counter for iterating through Measurements
        foreach ($r in $s.Measurements){                                                    #For each Measurement item
            $count ++                                                                           #Increment counter by 1 (in line with headers)
            $c_header = $headers_adj[$count]                                                    #Get the header respective of content
            $dataobj | Add-Member -MemberType NoteProperty -Name $c_header -Value $r            #Add this to the object for output
        }
        $out_obj += $dataobj
    }

    $out_obj | Export-Csv $export -Delimiter ',' -NoClobber -NoTypeInformation -Append -Force   #Output all as a CSV
    }
    catch {
        #Catch any errors that may occur and output them to console
        write-host "There was a problem..." -f DarkYellow
        write-host $error[0].CategoryInfo.Reason -f DarkYellow
        write-host $error[0].InvocationInfo.PositionMessage -f DarkYellow
    }
}
else{
    write-host "Path to import JSON file is invalid" -f DarkYellow
}
