<#
.SYNOPSIS
    Checks whether the "Register this connection's addresses in DNS" setting is enabled on the primary NIC of a list of servers.

.DESCRIPTION
    This script performs the following operations:
        1. Imports a CSV file containing server hostnames or IP addresses.
        2. Connects to each server via PowerShell Remoting (WinRM).
        3. Identifies the active network interface using WMI.
        4. Retrieves the DNS registration setting using Get-DnsClient.
        5. Optionally writes the result back into the original CSV file.

    Sample CSV format:
        hostname
        server01.domain.local
        server02.domain.local
        localhost

.REQUIREMENTS
    - PowerShell 5.1
    - WinRM enabled on target machines
    - Local admin rights on remote systems
    - CSV file with a valid hostname column
    - NetworkAdapter and DnsClient modules (built-in on Windows Server 2012+)

.NOTES
    Useful for auditing DNS registration settings across domain-joined servers.

    Variable guidance:
    - $csv_file: Full path to the CSV file containing the list of servers.
    - $hostname_property: Column name in the CSV that contains the server hostnames or IPs.
    - $addtoCSV: Set to $true to write results back into the CSV.
    - $addtoCSV_property: Column name in the CSV where the result should be written (if $addtoCSV is $true).
#>



#Variables:

$csv_file = "C:\Path\To\servers.csv"            #CSV full path
$hostname_property = "hostname"                 #Column name in CSV containing server hostnames/IP's
$addtoCSV = $true                               #Set to $true to place results into CSV
$addtoCSV_property = "Enabled"                  #Set to column name in CSV where results must be placed ($addtoCSV must be $true)

#Main Script:

try{
    write-host "Importing CSV" -f Green
    $csv = import-csv $csv_file -Delimiter ","                      #Attempt to import the CSV
}
catch{
    write-host "Unable to import CSV" -f Red
    pause                                                           #If CSV is not imported, halt the script
}

foreach ($i in $csv){                                               #Loop through each hostname in the CSV
    $invoke = $null                                                 #Set $invoke to $null on each loop

    write-host "Processing $($i.$hostname_property)" -f Green
    try{
        if ($i.$hostname_property -notmatch "localhost"){           #If the hostname is not 'localhost'

            #Create a PS session
            $session = New-PSSession -ComputerName $i.$hostname_property -ErrorAction SilentlyContinue
                $invoke = Invoke-Command -Session $session -ErrorAction SilentlyContinue -ScriptBlock {
                    #Get active NIC from WMI (using IPenabled property)
                $nicActive = Get-WmiObject win32_networkadapterconfiguration -Filter 'ipenabled = "true"' | select -first 1
                    #Get network adapter matching the same description as the one from WMI
                $getNic = Get-NetAdapter | where {$_.InterfaceDescription -eq $nicActive.Description}

                    #Use Get-DNSClient to get the advanced properties from the NIC
                $getProp = Get-DnsClient -InterfaceIndex $getNic.InterfaceIndex
                    #Get true/false response from RegisterThisConnectionAddress of the NIC
                $regDNS = $getProp | select -ExpandProperty RegisterThisConnectionsAddress
                    #Return response
                return $regDNS
                }
            }
        if ($i.$hostname_property -match "localhost"){              #If hostname is localhost
                #Get active NIC
            $nicActive = Get-WmiObject win32_networkadapterconfiguration -Filter 'ipenabled = "true"' | select -first 1
            $getNic = Get-NetAdapter | where {$_.InterfaceDescription -eq $nicActive.Description}

            $getProp = Get-DnsClient -InterfaceIndex $getNic.InterfaceIndex
            $regDNS = $getProp | select -ExpandProperty RegisterThisConnectionsAddress
                #Save response into variable
            $invoke = $regDNS
        }

        if ($invoke -match "$true|$false"){                         #If the response is either $true or $false
            if ($invoke -eq $true){
                write-host "Register DNS is " -NoNewline ; write-host "ENABLED " -f green -NoNewline ; write-host "for $($i.$hostname_property)"
            }
            if ($invoke -eq $false){
                write-host "Register DNS is " -NoNewline ; write-host "DISABLED " -f red -NoNewline ; write-host "for $($i.$hostname_property)"
            }
            if ($addtoCSV -eq $true){
                #If $addtoCSV is set to $true, then mark the 'enabled' column with the reply
                $i.$addtoCSV_property = $invoke
            }
        }
        else{
            write-host "Unable to retrieve NIC information from $($i.$hostname_property)" -f Red
        }
    }
    catch{
        write-host "Unable to connect to $($i.$hostname_property)" -f Red
    }
}

if ($addtoCSV -eq $true){
    remove-item $csv_file -Force                                            #Remove the old CSV
    $csv | Export-Csv -Path $csv_file -NoClobber -NoTypeInformation -Force  #Export the newly updated CSV
    write-host "Exported CSV" -f Green
}
