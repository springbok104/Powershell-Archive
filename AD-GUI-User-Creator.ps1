<#
.SYNOPSIS
    Launches a GUI-driven PowerShell tool for creating Active Directory user accounts using base role templates.

.DESCRIPTION
    This script opens a WPF interface that lets the user input name, domain, and site details. 
    A matching base account is selected from a list, and the script generates new user base on input

.EXAMPLE
    PS C:\Scripts> .\AD-GUI-User-Creator.ps1

    - Fill in the form with first name, last name, domain, and site.
    - Choose a base account template from the dropdown.
    - Click “Go” to create the AD user account:
        • A unique SamAccountName is generated
        • Group memberships and attributes are copied from the base account
        • A default password is applied and flagged for reset

.NOTES
    Requires PowerShell 5.1+, the ActiveDirectory module, and domain authentication.
    GUI logo and list entries are easily customizable via inline XAML and `$Base_Accounts` array.

.CONFIGURABLE VARIABLES
    $default_password      — Default password assigned to the new account
    $loc_address1 / $loc_address2  — Address info tied to each selectable site
    $OU_path               — Distinguished name path to base accounts (AD search context)
    $home_directory        — Path format with `<user>` placeholder for assignment

.DISCLAIMER
    This tool was built for internal automation. It is shared as is and may need tweaks to suit your AD setup. Please review before use
#>


#Configurable Variables
$default_password = "<password>"                                                                                         #Default password for all new AD accounts created
$loc_address1  = "physical address of OU 1"                                                                              #Physical address for loc1
$loc_address2 = "physical address of OU 2"                                                                               #Physical address for loc2
$OU_path = "OU=Users,OU=Base Accounts,DC=COMPANY,DC=COM"                                                                 #OU that contains the Base Accounts
$home_directory = "<directory"                                                                                           #Home profile directory. Script will replace <user> with new user SAMaccountname

$global:address = $null


Add-Type -AssemblyName PresentationFramework

[XML]$XAML  = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"

        Title="AD User Creator" Height="450" Width="650" BorderThickness="0" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Grid>
        <Label x:Name="heading_label" Content="Active Directory User Creation" Margin="200,50,160,0" FontSize="18" FontFamily="Calibri" FontWeight="Bold" Width="300" VerticalAlignment="Top"/>
        <Image x:Name="logo_image" Source="~\placeholder.png" HorizontalAlignment="Left" Height="100" Margin="10,10,0,0" VerticalAlignment="Top" Width="100"/>
        <GroupBox x:Name="left_groupbox" Header="User Details" HorizontalAlignment="Left" Height="200" Margin="10,130,0,0" VerticalAlignment="Top" Width="375" Panel.ZIndex="-1">
            <WrapPanel HorizontalAlignment="Left" Height="170" Margin="5,10,0,0" VerticalAlignment="Top" Width="360">
                <Label x:Name="firstname_label" Content="First Name: " Width="120" HorizontalAlignment="Left" Margin="5,15,0,0" Height="25"/>
                <TextBox x:Name="firstname_textbox" Height="25" Width="220" Margin="5,15,0,0" Cursor="Hand" BorderBrush="#FF546DB7" BorderThickness="2,1,5,1"/>
                <Label x:Name="lastname_label" Content="Last Name: " Width="120" HorizontalAlignment="Left" Margin="5,15,0,0" Height="25"/>
                <TextBox x:Name="lastname_textbox" Height="25" TextWrapping="Wrap" Width="220" Margin="5,15,0,0" Cursor="Hand" BorderBrush="#FF546DB7" BorderThickness="2,1,5,1"/>
                <Label x:Name="email_label" Content="Domain: " Width="120" HorizontalAlignment="Left" Margin="5,15,0,0" Height="25"/>
                <TextBox x:Name="email_textbox" Height="25" TextWrapping="Wrap" Width="220" Margin="5,15,0,0" Cursor="Hand" BorderBrush="#FF546DB7" BorderThickness="2,1,5,1"/>
                <Label x:Name="site_label" Content="Site: " Width="120" HorizontalAlignment="left" Margin="5,15,0,0" Height="25"/>
                <CheckBox x:Name="loc1_checkbox" Content="loc1" Margin="5,15,0,0" Cursor="Hand"/>
                <CheckBox x:Name="loc2_checkbox" Content="loc2" Margin="10,15,0,0" Cursor="Hand"/>
            </WrapPanel>
        </GroupBox>
        <GroupBox x:Name="right_groupbox" Header="Base AD Account:" HorizontalAlignment="Left" Height="200" Margin="390,130,0,0" VerticalAlignment="Top" Width="240" Panel.ZIndex="-1" ToolTip="">
            <ListBox x:Name="listbox" HorizontalAlignment="Left" Height="170" Margin="5,5,5,5" VerticalAlignment="Top" Width="220"/>
        </GroupBox>
        <Button x:Name="go_button" Content="Go!" HorizontalAlignment="Left" Margin="558,387,0,0" VerticalAlignment="Top" Width="75"/>
        <Button x:Name="clear_button" Content="Clear" HorizontalAlignment="Left" Margin="465,387,0,0" VerticalAlignment="Top" Width="75"/>
        <Label x:Name="status_label" Content="Status:" HorizontalAlignment="Left" Margin="10,384,0,0" VerticalAlignment="Top"/>
        <Label x:Name="status_edit" Content="" HorizontalAlignment="Left" Margin="70,384,0,0" VerticalAlignment="Top" Width="380" BorderThickness="0" BorderBrush="#FF8E3232"/>
    </Grid>
</Window>
"@ 

$reader = (New-Object System.Xml.XmlNodeReader $xaml)                                                                   #Setup dotnet xmlnodereader
$Window = [Windows.Markup.XamlReader]::Load($reader)                                                                    #Input the XAML content into the reader
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")  | ForEach {                                  #For each xml selectnodes path, get the control names
    New-Variable  -Name $_.Name -Value $Window.FindName($_.Name) -Force                                                 #Create a variable for each control to be called later
}

$status_edit.Content = "Please fill in all fields before continuing. Then click 'Go!'"

$clear_button.Add_Click({
    $firstname_textbox.Clear()
    $lastname_textbox.Clear()
    $email_textbox.clear()
    $loc2_checkbox.IsChecked = $false
    $loc1_checkbox.IsChecked = $false
    $listbox.SelectedItem = $Null
})


$Base_Accounts = @(
      "BA-Admin"
      "BA-Sales"
      "BA-Dev"
      "BA-Ops"
)

    $Base_Accounts | foreach {
        $listbox.items.add($_) | Out-Null
    }
    $loc1_checkbox.Add_Click({
        $global:address = $phys_address1 
    })
    $loc2_checkbox.Add_Click({
        $address = $phys_address2
    })

$go_button.Add_Click({

    $street = [regex]::Match($global:address, '[^,]*').value                                                                           #Get street number and name
    $city = ([regex]::Match($global:address, '\,(.*?)\,').value -replace ',').trim()                                                   #Get city name
    $state = [regex]::Match($global:address, '\,*([A-Z]{2})\s').value                                                                  #Get state abbreviation
    $zip = [regex]::Match($global:address, '[A-Z0-9]{5,6}').value   

    if ($firstname_textbox.text.Length -gt 0 -and $lastname_textbox.text.Length -gt 0 -and $email_textbox.Text.Length -gt 0 -and $listbox.SelectedItem -ne $null){
        $status_edit.Content = "Starting the creation process..."
        $new_sam = ($firstname_textbox.Text[0] + $lastname_textbox.text).ToLower()
        $fname = $firstname_textbox.Text
        $lname = $lastname_textbox.Text
        $validate_sam = Get-ADUser -Filter * | where {$_.SamAccountName -match $new_sam -or $_.name -match ($fname + " " + $lname)}
    if (($validate_sam | measure).count -eq 0){                                                                                     #If SamAccountName is not present in AD
        $sam_check = $true                                                                                                          #Set SamAccountName as is (eg. jsmith)
        }
    if (($validate_sam | measure).count -eq 1){                                                                                     #If there is an existing SamAccountName
        $lname = $lname + 2
        $new_sam = $new_sam + 2                                                                                                     #Add '2' onto the end   (eg. jsmith2)
        $sam_check = $true                                                                                                          #Set the check flag to $true
        }
        if (($validate_sam | measure).count -gt 1){                                                                                               #If there are more than 1 accounts with SamAccountName
        $last_sam_it = Get-ADUser -Filter * | where {$_.samaccountname -match $new_sam} | select -last 1 | select -ExpandProperty samaccountname  #get the highest numbered
    
        if ($last_sam_it -match[regex] '\d$'){                                                                                                  #If the highest number contains an integer
            [int]$last_int = [regex]::Match($last_sam_it, '(\d$)').value                                                                        #Get the integer from the SamAccountName
            $new_sam = ($last_sam_it -replace $last_int) + ($last_int + 1)                                                                      #Set new SamAccountName with integer + 1
            $lname = $lname + ($last_int + 1)
            $sam_check = $true
            write-host "Generated username: $new_sam" -f Green
            }
        }
    $base_name = $listbox.SelectedItem
    $UPN = $new_sam + '@' + $email_textbox.text

    if ($fname, $lname, $UPN, $sam_check, $Global:Address){
        $new_pass = $default_password | ConvertTo-SecureString -AsPlainText -Force                                   #Convert password to SecureString
        try{
        $source = get-aduser -Filter * -SearchBase $OU_path | where {$_.SamAccountName -eq $base_name}               #Get base account user
        }
        catch{
            write-host "OU path appears to be invalid." -f Red
            $write_out = Get-ADUser -Filter * | where {$_.samaccountname -eq $base_name}
            if ($write_out){
                write-host "Please check if you meant this as your OU: " -f Yellow
                write-host $($write_out).DistinguishedName -f yellow
            }
            else{
                write-host "Could not detect OU." -f Red
            }
            pause
        }
        write-host "Creating" -f gre
        New-ADUser -Name ($fname + " " + $lname) `
            -SamAccountName $new_sam `
            -AccountPassword $new_pass `
            -GivenName $fname `
            -Surname $lname `
            -StreetAddress $street `
            -City $city `
            -State $state `
            -PostalCode $zip `
            -country 'US' `
            -UserPrincipalName $UPN `
            -Instance $source `
            -EmailAddress $UPN `
            -ChangePasswordAtLogon $true `
            -Enabled $true 
    }
    else{
        $status_edit.Content = "Invalid parameters"
    }
    $check_ad = Get-ADUser -Filter * | where {$_.samaccountname -eq $new_sam}
    if ($check_ad){
        write-host "Creation of $new_sam successfull" -f Green
        $status_edit.Content = "Created Account - $new_sam"
        $home_dir = $home_directory -replace '<user>', $new_sam
        Set-ADUser $new_sam -HomeDirectory $home_dir
        $get_properties = get-aduser -Filter * -SearchBase $OU_path | where {$_.SamAccountName -eq $base_name} | get-adobject -properties *
        $group_member_source = get-aduser -Filter * -SearchBase $OU_path -Properties MemberOf | where {$_.SamAccountName -eq $base_name} | select -ExpandProperty memberof            #Get Base account memberships
        $group_member_destination = Get-ADUser -identity $base_name -Properties MemberOf | select -ExpandProperty memberof              #Get new account memberships
        $group_member_source | Add-ADGroupMember -Members $new_sam                                                                      #Add all Base account memberships to new account
        }
    }
})

[void]$Window.ShowDialog()