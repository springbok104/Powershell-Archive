<#
.SYNOPSIS
    Deploys and configures a new Hyper-V virtual machine from a predefined template.
.DESCRIPTION
    This PowerShell script interactively provisions a Hyper-V VM using a local VHD template.
    It supports dynamic or static memory, VM resource configuration, IP injection, optional domain join, IIS role installation, and custom monitoring setup—all handled from a single run.

.NOTES
    Requires: PowerShell 5+, Hyper-V module, WMI virtualization namespace access
    Assumes: Custom templates, working Hyper-V infrastructure, reachable domain controllers

    DISCLAIMER:
    This script is intended for internal testing, lab environments, or self-directed automation.
    It is provided as-is, with no warranties or guarantees.
    Use with caution in live environments—review all paths, credentials, and host configurations prior to execution.
#>


####################################################################
#Predefined Variables - Hyper-V Related
$VMGen = 1
$TemplateStorePath = "C:\Hyper-V\Virtual Hard Disk"
$MonitorStorePath = "C:\store\monitor\msiinstaller.msi"
$WWWrootFilesStorePath = "c:\store\wwwroot\*"
$VMHardDiskPath = "C:\Hyper-V\Virtual Hard Disk"
$VMPath = "C:\Hyper-V\Configuration"
$AutoStartAction = "Start" #nothing, start, StartIfRunning
$AutoStopAction = "Save" #Turnoff, save, shutdown
$AutoStartDelay  = 10

#Network Settings
$DHCP = $false
$VMVLAN = 0
$VMSwitchName = "vExternal"
$Domain = "domain.local"
$DomainDNS1 = "192.168.1.195"
$DomainDNS2 = "8.8.8.8"
$Subnet = "255.255.255.0"
$Gateway = "192.168.1.1"

#Script Variables
$CreateLogFile = $null #Setting this to a path (eg "c:\hvlog.txt") Will create a log at the end if any errors/warnings are triggered
$ChangeGuestHostname = $true #To match the VM name
$JoinToDomain = 1
$InstallIIS = 1
$InstallMonitor = 0
$VMGuestUsername = "Administrator"
$VMGuestPassword = "Password"

#Arrays for catching errors
$global:ErrorLog= @()
$global:ExceptionLog = @()
#####################################################################
$TimerElapsed = [System.Diagnostics.Stopwatch]::StartNew()
write-host "Starting Hyper-V Deployment script..." -f Green
#
#Prompt for information used for VM creation
#
$VMName = Read-Host -Prompt "Enter the VM Name"
$VMTemplate = Read-Host -Prompt "Enter the name of the template (Eg: 2012r2)"
[INT]$VMProcessorCount = read-host -Prompt "Enter number of processor cores (Eg: 4)"
[INT]$VMDynamicMemory = Read-Host -Prompt "Enable dynamic memory? (Eg: 0 or 1)"
    if ($VMDynamicMemory -eq 1){
    [int]$VMMemoryMin = read-host -Prompt "Enter the minimum memory allocated in GB. (Eg: 1)"
    [int]$VMMemoryMax = read-host -Prompt "Enter the maximum memory allocated in GB. (Eg: 4)"
    }
    if ($VMDynamicMemory -eq 0){
    [int]$VMMemory = read-host -Prompt "Enter the memory allocated in GB. (Eg: 4)"
    }
    if ($JoinToDomain -eq "1"){
    $DomainUsername = Read-Host -Prompt "Enter domain username, including domain name (Eg. corp\user)"
    $DomainPassword = read-host -Prompt 'test' -AsSecureString
}

$VMIPAddressAllocated = read-host -Prompt "Enter the IP address to allocate"
$HVHost = read-host -Prompt "Enter the Hyper-V host. (Eg: CT1-HV01)"

#Display all entered information to the user

        write-host "Starting deployment process of a new VM with the below specs..." -f Green
        write-host ""
        write-host "Name              :        $Vmname" -f DarkYellow
        write-host "Template          :        $VMTemplate" -f DarkYellow
        write-host "Core Count        :        $VMProcessorCount" -f DarkYellow
        write-host "Dynamic Memory    :        $VMDynamicMemory" -f DarkYellow
        write-host "Max Memory        :        $VMMemory" -f DarkYellow
        write-host "IP                :        $VMIPAddressAllocated" -f DarkYellow
        write-host "Hyper-V Host      :        $HVHost" -f DarkYellow
        write-host "VM Username       :        $VMGuestUsername" -f DarkYellow
        write-host "VM Password       :        $VMGuestPassword" -f DarkYellow
        write-host ""
        write-host "Options" -f Yellow
        write-host ""
        write-host "Join to domain    :        $JoinToDomain" -f DarkYellow
        write-host "Install IIS       :        $InstallIIS" -f DarkYellow
        write-host "Install Monitor   :        $InstallMonitor" -f DarkYellow
        if ($JoinToDomain){
        write-host "Domain            :        $Domain" -f DarkYellow
        write-host "Domain Account    :        $DomainUsername" -f DarkYellow}
        write-host "DNS Server 1      :        $DomainDNS1" -f DarkYellow
        write-host "DNS Server 2      :        $DomainDNS2" -f DarkYellow
        write-host "Subnet Mask       :        $Subnet" -f DarkYellow
        write-host ""

    $confirmproceed = read-host -Prompt "Confirm that you'd like to proceed? (y/n)"

#Functions
#Logging functions - Used to track/record any errors/warnings triggered during the process. $ErrorLog and $ExceptionLog can be called
Function LogWrite{
   Param ([string]$logstring, $warnorerror)
   if ($CreateLogFile -ne $null){
   Add-content $CreateLogFile -value ((Get-Date -format "dd-MM-yyyy HH:mm:ss") + " " + "::" + $warnorerror + "::" + " " + $logstring)
   }
   $global:ErrorLog += ((Get-Date -format "dd-MM-yyyy HH:mm:ss") + " " + "::" + $warnorerror + "::" + " " + $logstring)
   write-host "$warnorerror :" -f Red -NoNewline ; write-host " $logstring"
}

function LogException{
    Param($err, $errnote)
    write-host "Exception with $errnote. Please see Exception log" -f DarkYellow
    $ErrorObj = New-Object PSObject
    $ErrorObj | Add-Member -MemberType NoteProperty -name "Error" -Value ($_.Exception.Message)
    $ErrorObj | Add-Member -MemberType NoteProperty -Name "Line" -Value ($_.Exception.ErrorRecord.ScriptStackTrace.Substring($_.Exception.ErrorRecord.ScriptStackTrace.length - 2, 2))
    $ErrorObj | Add-Member -MemberType NoteProperty -Name "Cateogry" -Value ($_.CategoryInfo.Category)
    $ErrorObj | Add-Member -MemberType NoteProperty -name "Note" -Value $errnote
    $ErrorObj | Add-Member -MemberType NoteProperty -Name "Time" -Value (Get-Date -Format "dd-MMM: HH:mm")
    $global:ExceptionLog += $ErrorObj
    }

#Input Correction


if ($VMName.length -gt 15){Write-host "VMName cannot be longer than 15 chars" -f red ; LogWrite -logstring "VMName is more than 15 chars" -warnorerror "ERROR"}
if ($VMDynamicMemory -eq "0"){[int64]$VMMemory = $VMMemory * 1GB}
if ($VMDynamicMemory -eq 1){
[int64]$VMMemoryMin = $VMMemoryMin * 1GB
[int64]$VMMemoryMax = $VMMemoryMax * 1GB
}
if ([bool]($VMIPAddressAllocated -as [ipaddress]) -ne $true){
    LogWrite -logstring "IP Address entered is invalid ($VMIPAddressAllocated)" -warnorerror "ERROR"
    }

if (!(test-path $TemplateStorePath)){LogWrite -logstring "Innaccessible template storage path" -warnorerror "ERROR"}
if (!(Test-Path $MonitorStorePath)){LogWrite -logstring "Innaccessible monitor storage path" -warnorerror "WARNING"}
if (!(Test-Path $WWWrootFilesStorePath)){LogWrite -logstring "Innaccessible IIS WWWroot storage path" -warnorerror "WARNING"}


if ($global:ErrorLog -match "::ERROR::"){
    write-host "Errors have been detected with inputs:" -f DarkYellow
    write-host ""
    $global:ErrorLog | % {write-host $_ -f red}
    exit
    }

if ($global:ErrorLog -match "::WARNING::"){
    $confirmproceed = read-host -Prompt "Confirm that you'd like to proceed with the warnings? (y/n)"
    if ($confirmproceed -match "n|no"){
        exit
        }
    }

#Begin VM creation
if ($global:ErrorLog -notmatch "::ERROR::" -and $confirmproceed -match "y|yes"){
    #Import Hyper-V Module
    try{
    import-module Hyper-V -ErrorAction stop
    }
    catch{
    LogException -err $_ -errnote "Importing Hyper-V Module"
    LogWrite -logstring "Failure importing Hyper-V module" -warnorerror "ERROR"
    }

    try{
    #Create empty VM
    $error.clear()
    write-host "Creating VM $VMName on $HVHost..." -f darkGreen
    New-VM -VMName $VMName -Generation $VMGen -MemoryStartupBytes 1GB -Path $VMPath -NoVHD -ComputerName $HVHost -ErrorAction stop | Out-Null
    } #
    catch{
    LogException -err $_ -errnote "VM creation"
    LogWrite -logstring "Failure Creating VM" -warnorerror "ERROR"
    }
    finally{
        if ((get-vm $VMName).State -eq "off"){
            write-host "Starting configuration..." -f green
            try{
                $error.Clear()
                #Set the VM's RAM/Memory
                Set-VM -Name $VMName `
                       -ProcessorCount $VMProcessorCount `
                       -AutomaticStartAction $AutoStartAction `
                       -AutomaticStartDelay $AutoStartDelay `
                       -AutomaticStopAction $AutoStopAction `
                       -ComputerName $HVHost

                       write-host "Adding processor and memory" -f green
                       #Select dynamic or static memory configuration based on input
                    if ($VMDynamicMemory){
                        Set-VM -VMName $VMName -DynamicMemory -MemoryMinimumBytes $VMMemoryMin -MemoryMaximumBytes $VMMemoryMax -ComputerName $HVHost
                        }
                    else{Set-VM -VMName $VMName -StaticMemory -MemoryStartupBytes $VMMemory -ComputerName $HVHost}
            }
            catch{
                LogException -err $_ -errnote "Setting VM resources"
                LogWrite -logstring "Failure setting VM resources" -warnorerror "ERROR"
            }
            finally{
                if (!$error){
                    write-host "VM has been created and resources allocated" -f Green
                }
            }
            }
        }
        #Allocate resources to newly created VM
        #Find, copy and attach the VHD. 
        #Change boot order to VHDX
    try{
        $error.Clear()
        write-host "Fetching list of objects from storage..." -f Green
        $VHDToCopy = $TemplateStorePath | Get-ChildItem | where {$_.name -match $VMTemplate} | select -ExpandProperty FullName
        $VHDExt = $VHDToCopy.split(".") | select -Last 1
        $VHDNewPath = $VMHardDiskPath + "\" + "$VMName" + "." + "$VHDExt"
        write-host "Copying $VMTemplate VHDx from storage to destination. - " -f Green -NoNewline ; write-host "This may take a few minutes" -f yellow -NoNewline
        Copy-Item -Path $VHDToCopy -Destination $VHDNewPath
        write-host "VHDx copied. Retrieving network adapter for VM..." -f Green
        $PrimaryNetAdapter = Get-VM $VMName | Get-VMNetworkAdapter
    }
    catch{
    LogException -err $_ -errnote "Getting VHD from storage and retrieving VM network adapter"
    LogWrite -logstring "Failure getting VHD from storage and retrieving VM network adapter" -warnorerror "ERROR"
    }
    finally{
        if (!$error){
            try{
                #Attach VHD
                $error.Clear()
                write-host "Adding VHDx to VM, and setting boot order..." -f Green
                Add-VMHardDiskDrive -VMName $VMName -Path $VHDNewPath -ComputerName $HVHost
                $OsVirtualDrive = Get-VMHardDiskDrive -VMName $VMName -ControllerNumber 0 -ComputerName $HVHost
                    if ($VMGen -gt "1"){
                    Set-VMFirmware -VMName $VMName -FirstBootDevice $OsVirtualDrive -ComputerName $HVHost
                    }

                #Set VM network adapter settings
                write-host "Setting VM network settings..." -f Green
                get-vm -VMName $VMName | Get-VMNetworkAdapter | Set-VMNetworkAdapter `
                -VmqWeight 0 `
                -IPsecOffloadMaximumSecurityAssociation 0 `
                -IovWeight 0 `
                -MacAddressSpoofing Off `
                -DhcpGuard Off `
                -RouterGuard Off `
                -AllowTeaming Off `

                #Connect virtual switch
                Connect-VMNetworkAdapter -VMName $VMName -SwitchName $VMSwitchName 
                $PrimaryNetAdapter | Set-VMNetworkAdapterVlan -Untagged 
                sleep 1
            }
            catch [exception]{
            LogException -err $_ -errnote "Adding disk and setting VM network adapter"
            LogWrite -logstring "Failure adding VHDx and/or setting VM network adapter" -warnorerror "ERROR"
            }
            finally{
                if (!$error){
                    write-host "Completed creation of VM and resource allocation" -f Green
                    write-host "Starting VM" -f Green
                }
            }
        }
    }


write-host "Starting post-deployment process..." -f DarkGreen

#Start VM
#Inject IP address settings if adapter is present
if ((get-vm $VMName).State -ne "Running"){
    Start-VM -Name $VMName -ComputerName $HVHost
        Do {Start-Sleep -milliseconds 100}
        Until ((Get-VMIntegrationService $VMName | ?{$_.name -eq “Heartbeat”}).PrimaryStatusDescription -eq “OK”)Start-Sleep -s 15
    $GetVMNet = Get-VM $VMName | Get-VMNetworkAdapter
    if ($GetVMNet.connected -and $GetVMNet.SwitchName -eq $VMSwitchName){
        write-host "Confirmed VM is connected" -f Green
        }
    else{write-host "VM doesn't appear to be connected via network" -f red ; LogWrite -logstring "VM not connected to network" -warnorerror "ERROR"
         }
        }
    try{
        $error.Clear()
        write-host "Injecting IP settings into guest OS..." -f Green

        $wmi_vsms = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService 
        $wmi_cs = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName='$vmName'" 
        $wmi_vssd = ($wmi_cs.GetRelated("Msvm_VirtualSystemSettingData", "Msvm_SettingsDefineState", $null, $null, "SettingData", "ManagedElement", $false, $null) | % {$_})
        $wmi_ports = $wmi_vssd.GetRelated("Msvm_SyntheticEthernetPortSettingData")
        $wmi_portconfig = ($wmi_ports.GetRelated("Msvm_GuestNetworkAdapterConfiguration", "Msvm_SettingDataComponent",$null, $null, "PartComponent", "GroupComponent", $false, $null) | % {$_})
        $wmi_portconfig.DHCPEnabled = $false
        $wmi_portconfig.IPAddresses = @("$VMIPAddressAllocated")
        $wmi_portconfig.Subnets = @("$Subnet")
        $wmi_portconfig.DefaultGateways = @("$Gateway")
        $wmi_portconfig.DNSServers = @("$DomainDNS1", "$DomainDNS2")
        $wmi_vsms.SetGuestNetworkAdapterConfiguration($wmi_cs.Path, $wmi_portconfig.GetText(1)) | out-null
        sleep 3
    }
    catch{
        LogException -err $_ -errnote "Injection of IPv4 Address"
        LogWrite -logstring "Failure injecting IPv4 address into the guest OS" -warnorerror "ERROR"
    }
    finally{
        #Confirm that the VM is operational on the IP Address injected
        if (!$error){
        $error.Clear()
        $ConfirmVMIP = Get-VM $vmname | Get-VMNetworkAdapter | select -ExpandProperty IpAddresses
        $ConfirmVMIP = $ConfirmVMIP | where {$_ -match $VMIPAddressAllocated}
                    if ($ConfirmVMIP -match $VMIPAddressAllocated){
                          write-host "VM IP address has been configured" -f Green
                          write-host "Testing ICMP and WinRM response..." -f green
                          
                          if (Test-Connection $ConfirmVMIP -Count 1){
                              write-host "VM is responding to ICMP" -f Green
                              if (Test-NetConnection $ConfirmVMIP -Port 5985){
                                  write-host "VM is responding to WinRM" -f Green
                                  $ConfirmVMIP = $true
                                  $error.clear()
                                  }
                              else{write-host "VM is not responding on the IP assigned" -f Red ; LogWrite -logstring "VM is not responding on the IP assigned" -warnorerror "ERROR"}
                              }
                          
            }
        }
    }

if ($ConfirmVMIP -eq $true -and !$error){
#Create VM credentials used for PowerShell remoting
$VMPass = $VMGuestPassword | ConvertTo-SecureString -asPlainText -Force
$vmcreds = New-Object System.Management.Automation.PSCredential($VMGuestUsername,$VMPass)

if ($ChangeGuestHostname -or $JoinToDomain){
    $error.Clear()
    write-host "Preparing to change VM name" -f Green
    try{
    if ($ChangeGuestHostname -eq "1"){
        #Rename computer
        Invoke-Command -ComputerName $VMIPAddressAllocated -Credential $vmcreds -ArgumentList $VMName,$ChangeGuestHostname -ScriptBlock{
            $computerName = Get-WmiObject Win32_ComputerSystem
            $computerName.Rename($args[0]) | out-null
            write-host "Renamed guest OS. Restarting VM - " -f Green -NoNewline ; write-host "This may take a few minutes..." -f Yellow
            }
     }
     restart-computer -ComputerName $VMIPAddressAllocated -Credential $vmcreds -Force -Wait
     if (Test-Connection $VMIPAddressAllocated -count 1){
        if ($JoinToDomain -eq "1"){
        #Join computer to domain
        Invoke-Command -ComputerName $VMIPAddressAllocated -Credential $vmcreds -ArgumentList $Domain,$DomainUsername, $DomainPassword -ScriptBlock{
            $user = $args[1]
            $pass = $args[2]
            $dcreds = New-Object  System.Management.Automation.PSCredential ($user, $pass)

            Add-Computer -DomainName $args[0] -Credential $dcreds
            if (!$error){
                write-host "Joined to domain. Restarting VM..." -f Green
                }
            }
            }
        }
        restart-computer -ComputerName $VMIPAddressAllocated -Credential $vmcreds -force -Wait
        write-host "Computer restarting. Moving onto next phase." -f green
     }
     catch{
     LogException -err $_ -errnote "Setting of new VM guest computer name"
     LogWrite -logstring "Failed setting new guest computer name" -warnorerror "ERROR"
     }
     finally{
        try{
        if ($InstallIIS -eq "1"){
        $error.clear()
        #Install IIS
        #Copy monitor and IIS files
        write-host "Installing IIS role and management tools..." -f Green

        $IISInstalled = Invoke-Command -ComputerName $VMIPAddressAllocated -Credential $vmcreds -ArgumentList $WWWrootFilesStorePath, $MonitorStorePath -ScriptBlock{
            Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools -erroraction continue

            Copy-Item -Path $args[0] -Destination C:\InetPub\WWWroot -erroraction continue
            Copy-Item -Path $args[1] -Destination c:\ -erroraction continue

            $IISFeature = get-windowsfeature | where {$_.name -match "Web-Server"}
            if ($IISFeature.InstallState -eq "Installed"){
                return "$true"
                }
            }
            }
        }
        catch [Exception]{
        LogException -err $_ -errnote "Installing IIS and copying files"
        LogWrite -logstring "Failed installing IIS or copying files" -warnorerror "ERROR"
        }
        finally{
        $error.Clear()
            if ($IISInstalled -match $true){
                write-host "IIS has been installed and files copied" -f Green
                write-host "Proceeding to monitoring file installation..." -f Green
                }
            }
        }
    }
}

    try{
        $error.Clear()
        #Execute monitor .MSI file
        if ($InstallMonitor -eq "1"){
        Invoke-Command -ComputerName $VMIPAddressAllocated -Credential $vmcreds -ArgumentList $MonitorStorePath -ScriptBlock{
                      $msi = $args[0].split("\")[-1]
                      $installerpath = "C:\"
                      if ((Get-ChildItem $installerpath).name -match $msi){
                            Set-Location $installerpath
                            $joinedpath = $installerpath + "\" + $msi
                            Start-Process $joinedpath -ArgumentList “/qn” -Wait -ErrorAction Stop
                            }
                        }
                    }
    }
    catch{
        LogException -err $_ -errnote "Installing monitoring MSI"
        LogWrite -logstring "Failed to install monitoring MSI" -warnorerror "ERROR"
    }
    finally{
        if (!$error){
        #Show any errors and complete
        write-host "Installed monitoring .MSI" -f Green
        write-host ""
        $errc = $ErrorLog.count
        write-host "VM deployment process has been completed. With $errc errors/warnings" -f DarkYellow
        write-host ""
        $ErrorLog | % {write-host $_ -f DarkCyan}
        }

        #Write to log file if applicable
        if ($CreateLogFile){
            $ErrorLog | out-file -FilePath $CreateLogFile
            }
    }
}
$TimerElapsed.stop()
$TimeTaken = $TimerElapsed.Elapsed | select Minutes, Seconds
write-host "Job took:" -f Green
$TimeTaken
#EOF
