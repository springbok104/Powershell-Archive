<#
.SYNOPSIS
    Checks Active Directory users for password age and sends email notifications if passwords are older than a specified threshold.

.DESCRIPTION
    This script performs the following operations:
        1. Retrieves all enabled users from Active Directory.
        2. Calculates the number of days since each user's password was last set.
        3. Compares password age against a defined threshold.
        4. Sends email notifications to users whose passwords are nearing or past expiry.
        5. Optionally logs results to a CSV file.

    Sample CSV output (if logging is enabled):
        Username,EmailAddress,PasswordLastSet,DaysSinceLastSet
        jdoe, jdoe@example.com, 2024-03-01, 102
        asmith, asmith@example.com, 2024-04-15, 57

.REQUIREMENTS
    - PowerShell 5.1
    - ActiveDirectory module (RSAT)
    - SMTP server access (with or without authentication)
    - Domain-joined machine with appropriate permissions to query AD

.NOTES
    Useful for hybrid or on-prem AD environments to proactively manage password hygiene.

    Variables:
    - $scope: Set this to the number of days after which a password is considered stale (e.g. 90).
    - $logtoCSV: If set to $true, results will be exported to the path in $csvpath.
    - $smtpserver / $smtpport / $smtpuser / $smtppass: Configure these for your SMTP server.
#>

#Variables:
$scope = "90"                                                                                        #Number of days to check for unchanged passwords and greater (eg. "90")

#SMTP Settings
$SMTP_Server = "mydomain.co.za"                                                                      #SMTP server from where the mail will be authenticated and sent from 
$SMTP_From = "alerts@mydomain.com"                                                                   #From email address to send the notification
$SMTP_Password = ""                                                                                  #Password for above user account. If left empty, will try to send without authentication

#Logging Settings
$logging = "Enabled"                                                                                 #Setting to "Enabled" will create a .CSV log file
$logFile = "c:\mypath\test.csv"                                                                      #Set the path of the .CSV (Eg. "c:\automation\oldpasswords.csv"

#Testing Settings
$testing = "Enabled"                                                                                 #Setting this to "Enabled" will set a test email address, and not the users actual address
$testRecipient = "alerts@mydomain.com"                                                               #Testing email address if $testing is set to "Enabled"

#End of Variables:

$textEncoding = [System.Text.Encoding]::UTF8                                                         #Set email encoding type to UTF8
$date = Get-Date -format ddMMyyyy                                                                    #Set date format for log .csv

Import-Module ActiveDirectory                                                                        #Import ADDS module, and get list of all enabled AD users
$UserList = Get-ADUser -filter * -properties Name, PasswordExpired, PasswordLastSet, EmailAddress | where {$_.Enabled -notmatch "False"}

if (($logging) -eq "Enabled"){ 

    $logfilePath = (Test-Path $logFile) 

    if (($logFilePath) -ne "True"){ 

        New-Item $logfile -ItemType File 
        Add-Content $logfile "Date,Name,EmailAddress,PasswordLastSet"                                 #Create a log file with Date, Name, EmailAddress, PasswordLastSet
        } 
} 

[int]$counter = "1"                                                                                   #Start the counter at "1"

foreach ($i in $UserList){                                                                            #Foreach loop, to process each user in AD
        
        [int]$count = $UserList.Count                                                                 #Create a counter to show progress through user list  

        $name = $i.Name
        write-host "Checking user: $name" -f Green -NoNewline
        write-host " [$counter/$count]" -f DarkYellow
        $counter ++
    
    if ($i.passwordlastset.length -gt 0){

        $result = $i | select -ExpandProperty PasswordLastSet                                           #Get the "PasswordLastSet" property from AD
        $today = (get-date)                                                                             #Get todays date
        $changed_last = New-TimeSpan –Start $result –End $today | select -ExpandProperty Days           #Compare time difference between the PasswordLastSet property and todays date, get the number of days
        
        if ($changed_last -gt $scope){
            
            write-host "$name last changed their password in $changed_last days" -f Yellow                #Set email properties (Name, Email Address, PasswordLastSet information)
            $emailaddress = $i.emailaddress

            $messageDays = "$changed_last" + " days " + "ago."                                           #Set the message for the user
                                                                                                         #Set the email body for the user
            $body ="
                Dear $name, 
                <p> Your Password was last changed $messageDays<br> 
                To change your password on a PC press CTRL ALT Delete and chose Change Password <br> 
                <p>Thanks, <br>  
                </P>" 

             if ($testing -eq "Enabled"){ 
                $emailaddress = $testRecipient                                                            #If $testing is enabled, set the recipient email to the $testrecipient email address
                } 
 
            if ($emailaddress -eq $null){ 
                $emailaddress = $testRecipient     
                }

            $SMTP_Subject = "Your password was last changed $messageDays"

            if ($logging -eq "Enabled"){ 
                Add-Content $logfile "$date,$Name,$emailaddress"                                           #Add to log file
            }
            
                if ($SMTP_Password){
                    $pass = $SMTP_Password | ConvertTo-SecureString -AsPlainText -Force                    #if $SMTP_Password is set, convert it to a secure string
                    $credentials = New-Object System.Management.Automation.PsCredential("$SMTP_From",$pass)#Create a .Net credentials object for authentication of the email account for sending

                    write-host "Sending email for $name" -f Yellow
                    Send-Mailmessage -smtpServer $SMTP_Server -from $SMTP_From -to $emailaddress -subject $SMTP_Subject -body $body -bodyasHTML -priority High -Encoding $textEncoding -Credential $credentials
                    }

                if ($SMTP_Password -eq $null){      
                    write-host "Sending email for $name" -f Green                                          #If the $SMTP_Password field is emtpy, don't send with authentication (from within an organisation)
                    Send-Mailmessage -smtpServer $SMTP_Server -from $SMTP_From -to $emailaddress -subject $SMTP_Subject -body $body -bodyasHTML -priority High -Encoding $textEncoding
                    }
                }
            }
}
