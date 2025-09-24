<#
.SYNOPSIS
    Imports and creates Active Directory user accounts from a CSV file.
.DESCRIPTION
    This PowerShell script reads user information from a structured CSV file and creates new Active Directory accounts accordingly.
    It supports assigning users to specific organizational units (OU), setting passwords (if included), and gracefully handling errors.
    Users without passwords are created as disabled accounts to meet security best practices. Optionally, an override OU can be set 
    to apply a consistent target location for all accounts.
.EXAMPLE
    Bulk-ADUser-Creator.ps1 -CSV_Path "C:\Scripts\ad-users.csv" -Password_Column_name "password" -Override_OU "OU=NewUsers,DC=contoso,DC=com"
.NOTES
    Requires the ActiveDirectory module.
    Ensure the CSV contains the following fields: objectClass, sAMAccountName, dn, and optionally password.

    Sample CSV:
    objectClass,sAMAccountName,dn,password
    User,jdoe,"CN=John Doe,OU=Sales,DC=contoso,DC=com",P@ssw0rd123
    User,asmith,"CN=Alice Smith,OU=HR,DC=contoso,DC=com",Secure!Pass456
    User,btaylor,"CN=Bob Taylor,OU=IT,DC=contoso,DC=com",

    DISCLAIMER:
    This script is intended for internal testing, lab environments, or self-directed automation.
    It is provided as-is, with no warranties or guarantees.
    Use with caution in live environments—review all paths, credentials, and host configurations prior to execution.
#>

[CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $CSV_Path,                                                                          #CSV file path 
        $Override_OU = $null,                                                               #Set this to an OU string if the OU isn't given in the CSV. Leave as $null otherwise
        $Password_Column_name                                                               #If there is a 'password' column in the CSV, set the name of the column here so that the script can set the password for the account
    )

#Variable:
$CSV_Delimiter = ","                                                                        #Set the delimiter that the CSV will be read with ("," by default)

#End of Variable

Import-Module ActiveDirectory         

$UserList = Import-Csv -Path $CSV_Path -Delimiter $CSV_Delimiter                            #Get all the users from the CSV that needs to be added to AD, including all columns

foreach ($i in $UserList){
    
    $password = $null                                                                       #Initialise the $password variable to $null
    $continue = $true

    $SamAccountName = $i.sAMAccountName                                                     #Prepare sAMAccountName
    $FullName = ($i.dn.Split(",") | where {$_ -match "CN="}) -replace "CN=",""              #Prepare FullName by splitting the "dn" path by "CN=" and grabbing the name
    $FirstName = $FullName.split(" ")[0]                                                    #Prepare FirstName by splitting FullName into two
    $LastName = $FullName.split(" ")[-1]                                                    #Prepare LastName by splitting FullName into two, and getting the last name
    $OU = ($i.dn.Split(",") | where {$_ -match "OU="}) -replace "OU=",""                    #Prepare OU name by splitting "dn" path by "OU=" and getting the name
    $Type = $i.objectClass                                                                  #Prepare object type

    write-host "Processing user: " -f Green -NoNewline
    write-host "$SamAccountName " -f Magenta -NoNewline
    
    if ($i.$Password_Column_name -gt 0){                                                    #If password column contains a password, convert it to secure string
        $password = ConvertTo-SecureString -String "$i.$Password_Column_name" -AsPlainText -Force
    }

    if ($Type -ne "User"){                                                                  #If the Type is not a 'user', exit the loop and carry on
        break;
        }

    if ($Override_OU -ne $true){                                                            #If you have not specified an overide OU (use CSV) then continue
        
        $UseOU = Get-ADOrganizationalUnit -Filter * | where {$_.name -match $OU}            #Get the AD OU object matching same name as OU found in CSV
        
        if ($UseOU){
            $UseOU = $UseOU.DistinguishedName                                               #Get the OU DN

                try{
                    if ($password -eq $null){                                               #If Password doesn't exist, create the user as a disabled user
                    New-ADUser -Name $SamAccountName `
                        -GivenName $FirstName `
                        -Surname $LastName `
                        -SamAccountName $SamAccountName `
                        -Path $UseOU `
                        -Enabled $false
                        } 
                    if ($password -ne $null){                                               #If Password does exist, create user as an enabled user
                    New-ADUser -Name $SamAccountName `
                        -GivenName $FirstName `
                        -Surname $LastName `
                        -SamAccountName $SamAccountName `
                        -Path $UseOU `
                        -AccountPassword $Password `
                        -Enabled $true
                    }
                }
                catch{                                                                      #Catch any error during creation process, output error details
                    write-host "Failed adding user to AD: " -f Yellow -NoNewline
                    write-host $SamAccountName -f Magenta -NoNewline
                    write-host " [SKIPPING] " -f Red
                    write-host "ERROR : " -f Yellow -NoNewline
                    write-host $Error[0].CategoryInfo.Reason -f DarkYellow 
                    $continue = $false
                }
                finally{
                if ($continue -ne $false){                                                  #If there is no error, output that the user creation was a success
                    write-host "User added to AD: " -f Cyan -NoNewline
                    write-host $SamAccountName -f Magenta -NoNewline
                    write-host " [OK] " -f Green
                    }
                }
            }

        if (!$UseOU){                                                                       #If there is no OU found, output an error
            write-host "OU not found for user, " -f Yellow -NoNewline
            write-host $SamAccountName -f Magenta -NoNewline
            write-host " matching OU, " -f Yellow -NoNewline 
            write-host $UseOU -f Magenta -NoNewline
            write-host " [SKIPPING] " -f Red
        }
    }

    if ($Override_OU -ne $null -or $Override_OU.count -gt 0){                               #If you have specified $Override_OU, foreach will use this
        
        $UseOU = Get-ADOrganizationalUnit -Filter * | where {$_.distinguishedname -eq $Override_OU}
        $UseOU = $UseOU[0].DistinguishedName

        if ($UseOU){

            try{
                    if ($password -eq $null){
                    New-ADUser -Name $SamAccountName `
                        -GivenName $FirstName `
                        -Surname $LastName `
                        -SamAccountName $SamAccountName `
                        -Path $UseOU `
                        -Enabled $false
                        }
                    if ($password -ne $null){
                    New-ADUser -Name $SamAccountName `
                        -GivenName $FirstName `
                        -Surname $LastName `
                        -SamAccountName $SamAccountName `
                        -Path $UseOU `
                        -AccountPassword $Password `
                        -Enabled $true
                    }
                }
                catch{
                    write-host "Failed adding user to AD: " -f Yellow -NoNewline
                    write-host $SamAccountName -f Magenta -NoNewline
                    write-host " [SKIPPING] " -f Red
                    write-host "ERROR : " -f Yellow -NoNewline
                    write-host $Error[0].CategoryInfo.Reason -f DarkYellow 
                    $continue = $false
                }
                finally{
                if ($continue -ne $false){
                    write-host "User added to AD: " -f Cyan -NoNewline
                    write-host $SamAccountName -f Magenta -NoNewline
                    write-host " [OK] " -f Green
                    }
                }
            }
        }
    }
write-host ""
write-host "NOTE: " -f Red -NoNewline
write-host "AD accounts without a password in the CSV have been created as a disabled account, and need to be manually enabled." -f Yellow
write-host ""
write-host "Script finished" -f Green
