<#
    This script checks the current BIOS version and compares it to the latest available version from the manufacturer. If an update is needed, it downloads and installs the update, then prompts the user to reboot. Requires Reboot Tool to be installed.
    Requires Toast Notification to be installed.
    HP BIOS update requires HPCMSL PowerShell module.
    https://github.com/damienvanrobaeys/Lenovo_BIOS_Auto_Update
    https://github.com/gwblok/garytown/blob/master/RunScripts/Update-HPBIOS.ps1
    https://github.com/MSEndpointMgr/Intune/tree/master/Firmware/Intune%20BIOS%20Update%20Control/BIOSUpdate_PR
    https://github.com/gwblok/garytown/blob/master/Intune/Update-HPCSML.ps1
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Path to store log file. Default is Intune Management Extension log folder.")]
    [string]$IntuneManagementExtensionPath = $(Join-Path -Path $env:ProgramData "Microsoft\IntuneManagementExtension\Logs"),
    [parameter(Mandatory = $false, HelpMessage = "Path to Reboot Tool and Toast Notification scripts.")]
    [string]$ToastNotificationPath = "$(${env:ProgramFiles(x86)})\Contoso\Reboot\",
    [parameter(Mandatory = $false, HelpMessage = "Password for HP BIOS update if BIOS is password protected.")]
    [string]$HpBIOSPassword = $null,
    [parameter(Mandatory = $false, HelpMessage = "Password for Lenovo BIOS update if BIOS is password protected.")]
    [string]$LenovoBIOSPassword = $null,
    [parameter(Mandatory = $false, HelpMessage = "Defines the maximum age of the latest BIOS update to be installed. This is to prevent installing very new BIOS updates that might cause issues. Set to 0 to disable this check.")]
    [int]$LatestBIOSDays = 14,
    [parameter(Mandatory = $false, HelpMessage = "Set to false to only detect if a BIOS update is needed, but do not install it.")]
    [bool]$Remediate = $true,
    [parameter(Mandatory = $false, HelpMessage = "Set to true to ignore AC power check. Not recommended, as BIOS updates usually require AC power.")]
    [bool]$IgnoreACPowerCheck = $false
)

[string]$Global:LogFilePath = $(Join-Path -Path $IntuneManagementExtensionPath -ChildPath 'BIOS_Update.log')
[string]$Global:ToastNotificationPath = $ToastNotificationPath

function Write-Log
{
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogText,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string]$Component = '',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Information','Warning','Error')]
        [string]$Type = 'Information',

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [int]$Thread = $PID,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string]$File = '',

        [Parameter(Mandatory = $false)]
        [int]$LogMaxSize = 2.5MB,

        [Parameter(Mandatory = $false)]
        [int]$LogMaxHistory = 1
    )
    
    Begin
    {
        switch ($Type)
        {
            'Information' { $TypeNum = 1 }
            'Warning'     { $TypeNum = 2 }
            'Error'       { $TypeNum = 3 }
        }
    
        if (-not $Global:LogFilePath) {
            Write-Error -Message 'Variable $LogFilePath not defined in scope $Global:'
            exit 1
        }
        
        if (-not (Test-Path -Path $Global:LogFilePath -PathType Leaf)) {
            New-Item -Path $Global:LogFilePath -ItemType File -ErrorAction Stop | Out-Null
        }
        
        $LogFile = Get-Item -Path $Global:LogFilePath
        if ($LogFile.Length -ge $LogMaxSize) {
            $ArchiveLogFiles = Get-ChildItem -Path $LogFile.Directory -Filter "$($LogFile.BaseName)*.log" | Where-Object {$_.Name -match "$($LogFile.BaseName)-\d{8}-\d{6}\.log"} | Sort-Object -Property BaseName
            if ($ArchiveLogFiles.Count -gt $LogMaxHistory) {
                $ArchiveLogFiles | Select-Object -Skip ($ArchiveLogFiles.Count - $LogMaxHistory) | Remove-Item
            }

            $NewFileName = "{0}-{1:yyyyMMdd-HHmmss}{2}" -f $LogFile.BaseName, $LogFile.LastWriteTime, $LogFile.Extension
            $LogFile | Rename-Item -NewName $NewFileName
            New-Item -Path $Global:LogFilePath -ItemType File -ErrorAction Stop | Out-Null
        }

            Write-Verbose -Message $LogText
    }
    
    Process
    {
        $now = Get-Date
        $Bias = ($now.ToUniversalTime() - $now).TotalMinutes
        [string]$Line = "<![LOG[{0}]LOG]!><time=`"{1:HH:mm:ss.fff}{2}`" date=`"{1:MM-dd-yyyy}`" component=`"{3}`" context=`"`" type=`"{4}`" thread=`"{5}`" file=`"{6}`">" -f $LogText, $now, $Bias, $Component, $TypeNum, $Thread, $File
        $Line | Out-File -FilePath $Global:LogFilePath -Encoding utf8 -Append -ErrorAction Stop
    }
    
    End
    {
    }
}

function Test-RebootPending {
	
	[CmdletBinding()]
    param (
        [bool]$WindowsUpdate = $true,
        [bool]$CBS = $true,
        [bool]$PendingFileRename = $true,
        [bool]$DomainJoin = $true,
        [bool]$ServerManager = $true
    )
	
    function Test-RegistryValue {
        param (
            [parameter(Mandatory)][string]$Path,
            [parameter(Mandatory)][string]$Value
        )
        try {
            Get-ItemProperty -Path $Path -Name $Value -ErrorAction Stop | Out-Null
            $true
        } catch {
            $false
        }
    }

    $PendingReboot = $false

    # Registry keys to check
    $keys = @()
	$values = @()
	
	if ($WindowsUpdate) {
		$keys += "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
        $keys += "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting"
	}
	
	if($CBS) {
		$keys += "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
		$values += @{ Path="HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing"; Name="RebootInProgress" }
        $values += @{ Path="HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing"; Name="PackagesPending" }
	}
	
	if ($PendingFileRename) {
		$values += @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"; Name="PendingFileRenameOperations" }
        $values += @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"; Name="PendingFileRenameOperations2" }
	}
	
	if($ServerManager) {
		$keys += "HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts"
		$values += @{ Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"; Name="DVDRebootSignal" }
	}
	
	if ($DomainJoin) {
		$values += @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon"; Name="JoinDomain" }
        $values += @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon"; Name="AvoidSpnSet" }
    }

    # Check keys
    foreach ($key in $keys) {
        if (Test-Path $key) {
            Write-Verbose $key
            $PendingReboot = $true
        }
    }

    # Check values
    foreach ($item in $values) {
        if (Test-RegistryValue -Path $item.Path -Value $item.Name) {
            Write-Verbose "$($item.Path) > $($item.Name)"
            $PendingReboot = $true
        }
    }

    return $PendingReboot
}

function Show-ToastMessage(){
	[CmdletBinding()]
    param (
        [string]$ToastScript = (Join-Path -Path $Global:ToastNotificationPath -ChildPath "Remediate-ToastNotification.ps1"),
		[string]$ToastConfig = (Join-Path -Path $Global:ToastNotificationPath -ChildPath "config-toast-biosupdate.xml"),
		[string]$PSInvoker = (Join-Path -Path $Global:ToastNotificationPath -ChildPath "PSInvoker.exe")
    )
	
	$Component = "ToastMessage"
	
	$TaskName = 'TempToast'

    if(((Test-Path $ToastScript) -eq $false) -or ((Test-Path $ToastConfig) -eq $false) -or ((Test-Path $PSInvoker) -eq $false)){
        Write-Log -Component $Component -LogText "One or more required files for Toast Notification not found" -Type Error
        return
    }
	
	Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

	$TaskAction = New-ScheduledTaskAction -Execute $PSInvoker -Argument "`"$ToastScript`" `"$ToastConfig`""
	$TaskPrincipal = New-ScheduledTaskPrincipal -GroupId S-1-5-32-545
	$Task = New-ScheduledTask -Action $TaskAction -Principal $TaskPrincipal

	$ScheduledTask = $null
	try {
		Write-Log -Component $Component -LogText "Trying to show toast notification"
		$ScheduledTask = Register-ScheduledTask -TaskName $TaskName -TaskPath '\' -InputObject $Task
		Start-ScheduledTask -InputObject $ScheduledTask
	} finally {
		if ($ScheduledTask) {
			Unregister-ScheduledTask -InputObject $ScheduledTask -Confirm:$false
		}
	}
	
	Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
}

if ($Remediate -eq $true){ $Component = "BIOS - Remediation" } else {$Component = "BIOS - Detection"}
Write-Log -Component $Component -LogText "Script started"

# Check pending reboot
if((Test-RebootPending -PendingFileRename $false) -contains $true){
    $Component = "Pending Reboot Check"
	Write-Log -Component $Component -LogText "Pending Reboot. Aborting BIOS update."
	Show-ToastMessage -ToastConfig "$ToastNotificationPath\config-toast-pendingreboot.xml"
    exit 1
}

# --- AC POWER CHECK ---
try {
    $Component = "AC POWER CHECK"

	Write-Log -Component $Component -LogText "Checking if device is connected to AC power."
        
	$PowerStatus = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue

	if ($PowerStatus) {
		# BatteryStatus 2 = Charging, 6 = Charging and High, 7 = Charging and Low, 8 = Charging and Critical
		if ($PowerStatus.BatteryStatus -notin 2,6,7,8 -and $IgnoreACPowerCheck -eq $false) {
			Write-Log -Component $Component -LogText "Device is NOT connected to AC power. Aborting BIOS update."
			exit 1
		} elseif($IgnoreACPowerCheck -eq $true){
			Write-Log -Component $Component -LogText "AC power check is ignored by configuration. Continuing with BIOS update." -Type Warning
		}
	}
	else {
		Write-Log -Component $Component -LogText "No battery detected (likely desktop) -> continuing"
	}
}
catch {
    Write-Log -Component $Component -LogText "Could not determine power status: $_"
    exit 1
}

$ComputerInfoDetails = Get-ComputerInfo
if ($ComputerInfoDetails.CsUserName -match "defaultUser") {
	$Component = "ESP Installation"
	Write-Log -Component $Component -LogText "Device in enrollment status. Aborting BIOS update."
	exit 1
}

$Manufacturer = (Get-CimInstance Win32_ComputerSystem).Manufacturer

if ($Manufacturer -match "HP")
{
	# --- HPCMSL ---
	Import-Module HPCMSL -ErrorAction SilentlyContinue

	if (-not (Get-Module HPCMSL))
	{
		$Component = "HPCMSL"
		Write-Log -Component $Component -LogText "HPCMSL not available"
		exit 1
	}

	try {
		$Component = "HP BIOS"
		$BIOSVersion = Get-HPBIOSVersion
		$LatestHPBIOS = Get-HPBIOSUpdates -Latest
    } catch {
        Write-Log -Component $Component -LogText "Error while retrieving BIOS information: $_" -Type Error
        exit 1  
    }

    if ([datetime]$LatestHPBIOS.Date -gt (Get-Date).AddDays(-($LatestBIOSDays))) {
        Write-Log -Component $Component -LogText "BIOS update is newer than $($LatestBIOSDays) days. Not installing yet!"
        exit 0
    }

    if ([System.Version]$LatestHPBIOS.Ver -gt [System.Version]$BIOSVersion -and $Remediate -eq $true)
    {

        Write-Log -Component $Component -LogText "Updating BIOS: $BIOSVersion -> $($LatestHPBIOS.Ver)"

        try {
            $BIOSPassSet = Get-HPBIOSSetupPasswordIsSet

            if ($BIOSPassSet)
            {
                #Get-HPBIOSUpdates -Flash -Quiet -Yes -Password $HpBIOSPassword
                Write-Log -Component $Component -LogText "BIOS has password" -Type Error
                exit 1
            }
            else
            {
                Get-HPBIOSUpdates -Flash -Quiet -Yes -BitLocker Suspend
            }

            Write-Log -Component $Component -LogText "BIOS update staged successfully"
        }
        catch {
            Write-Log -Component $Component -LogText "Error during BIOS update: $_" -Type Error
            exit 1
        }

        try {   
            Show-ToastMessage

            # Give firmware staging time
            #Start-Sleep -Seconds 30

            # --- FORCED REBOOT ---
            #shutdown.exe /r /t 60 /c "BIOS update installed. System will reboot to complete the update." /f
        }
        catch {
            Write-Log -Component $Component -LogText "Toast notification failed: $_" -Type Error
        }

        exit 0

    } elseif ([System.Version]$LatestHPBIOS.Ver -gt [System.Version]$BIOSVersion -and $Remediate -eq $false) {
        Write-Log -Component $Component -LogText "BIOS update available: $BIOSVersion -> $($LatestHPBIOS.Ver)"
        exit 1
    } else {
        Write-Log -Component $Component -LogText "BIOS is already up-to-date: $BIOSVersion"
        exit 0
    }

} elseif ($Manufacturer -eq "lenovo"){

    $Component = "Lenovo BIOS"
	
	$WMI_computersystem = Get-CimInstance Win32_ComputerSystem
    $Get_MTM = ($WMI_computersystem.Model.SubString(0, 4)).Trim()
	
	$OS_Ver = (Get-ciminstance Win32_OperatingSystem).Caption
	If($OS_Ver -like "*10*"){$WindowsVersion = "win10"}ElseIf($OS_Ver -like "*11*"){$WindowsVersion = "win11"}
	$CatalogUrl = "https://download.lenovo.com/catalog/$Get_MTM`_$WindowsVersion.xml"
	[System.Xml.XmlDocument]$CatalogXml = $null
	try	{
		$CatalogXml = (New-Object -TypeName System.Net.WebClient).DownloadString($CatalogUrl)
	}
	catch {	
		Write-Log -Component $Component -LogText "Can not get BIOS Catalog info from Lenovo: $_" -Type Error
		exit 1 		
	}
	
	$PackageUrls = ($CatalogXml.packages.ChildNodes | Where-Object { $_.category -match "BIOS UEFI" }).location | Sort-Object | Select-Object -Last 1
	[System.Xml.XmlDocument]$PackageXml = $null
	if(($null -ne $PackageUrls) -and ($PackageUrls.Count -eq 1))
	{
		$PackageXml = (New-Object -TypeName System.Net.WebClient).DownloadString($PackageUrls)		
	} else {	
		Write-Log -Component $Component -LogText "No BIOS Packages found for Lenovo model $Get_MTM" -Type Error
		exit 1 			
	}
	
	$baseUrl = $PackageUrls.Substring(0,$PackageUrls.LastIndexOf('/')+1)
	$LatestLenovoBIOS = $PackageXml.Package	
	if($null -eq $LatestLenovoBIOS)	{
		Write-Log -Component $Component -LogText "Can not get BIOS info from Lenovo: $_" -Type Error
		exit 1
	}
	
	if ([datetime]$LatestLenovoBIOS.ReleaseDate -gt (Get-Date).AddDays(-($LatestBIOSDays))) {
		Write-Log -Component $Component -LogText "BIOS update is newer than $($LatestBIOSDays) days. Not installing yet!"
		exit 0
	}
	
	$BIOS_info = get-ciminstance win32_bios | Select-Object *
	$BIOS_Maj_Version = $BIOS_info.SystemBiosMajorVersion 
	$BIOS_Min_Version = $BIOS_info.SystemBiosMinorVersion 
	$BIOSVersion = "$BIOS_Maj_Version.$BIOS_Min_Version"
	
	$LatestBIOSVersion = $LatestLenovoBIOS.version

	# Check if LatestBIOSVersion is a number
	if([System.Version]::TryParse($LatestBIOSVersion, [ref]$null)){
		
		if([System.Version]$LatestBIOSVersion -gt [System.Version]$BIOSVersion -and $Remediate -eq $true) {
			
			Write-Log -Component $Component -LogText "Downloading BIOS: $LatestBIOSVersion"
			Invoke-WebRequest -Uri ($baseUrl + $PackageXml.Package.Files.Installer.File.Name) -OutFile ("$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestBIOSVersion).exe")
			If(Test-Path ("$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestBIOSVersion).exe")){
				Write-Log -Component $Component -LogText "Updating BIOS: $BIOSVersion -> $LatestBIOSVersion"
				$Extract_Folder_Path = $null
				try	{
					Write-Log -Component $Component -LogText "Trying to extract BIOS update"
					$Extract_Folder_Path = "$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestBIOSVersion)"
					Start-Process -FilePath ("$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestBIOSVersion).exe") -ArgumentList "/VERYSILENT /DIR=$Extract_Folder_Path /EXTRACT=YES" -PassThru -Wait
					
					$FlashSwitches = " /S"
					if ($LenovoBIOSPassword)
					{
						$FlashSwitches = $FlashSwitches + " /pass:$($LenovoBIOSPassword)"
						Write-Log -Component $Component -LogText "BIOS has password" -Type Error
						exit 1
					}

					$WinUPTPUtility = $null
					if ([Environment]::Is64BitOperatingSystem) {
						$WinUPTPUtility = Get-ChildItem -Path $Extract_Folder_Path -Filter "*.exe" -Recurse | Where-Object { $_.Name -like "WinUPTP64.exe" } | Select-Object -ExpandProperty FullName
					}

					if (!($WinUPTPUtility)) {
						$WinUPTPUtility = Get-ChildItem -Path $Extract_Folder_Path -Filter "*.exe" -Recurse | Where-Object { $_.Name -like "WinUPTP.exe" } | Select-Object -ExpandProperty FullName
					}

					if(Test-Path $WinUPTPUtility){
						Write-Log -Component $Component -LogText "Disable BitLocker for one reboot"
						#& cmd.exe /c "manage-bde -protectors -disable C:"
						if ((Manage-Bde -Status C:) -match "Protection On") {
							Suspend-BitLocker -MountPoint "$($env:SystemDrive)" -RebootCount 1
						}

						Write-Log -Component $Component -LogText "Tryig to install BIOS Update: $WinUPTPUtility $FlashSwitches"
						$FlashProcess = Start-Process -FilePath $WinUPTPUtility -ArgumentList "$FlashSwitches" -Passthru -Wait

						Write-Log -Component $Component -LogText "BIOS Update installed with exit code: $($FlashProcess.ExitCode)"
					}
					
					try {   
						Show-ToastMessage
					}
					catch {
						Write-Log -Component $Component -LogText "Toast notification failed: $_" -Type Error
					}
				}
				catch {
					Write-Log -Component $Component -LogText "Error during last BIOS action" -Type Error
					
					$BLinfo = Get-Bitlockervolume | Where-Object { $_.MountPoint -eq $env:SystemDrive}
					if($blinfo.ProtectionStatus -ne 'On'){
						Write-Host "Enable Bitlocker"
						Resume-BitLocker -MountPoint ($BLinfo.MountPoint)
					}

					if($Extract_Folder_Path){
						Remove-Item -Path $Extract_Folder_Path -Force -Recurse -ErrorAction SilentlyContinue
					}
					Remove-Item -Path ("$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestBIOSVersion).exe") -Force -ErrorAction SilentlyContinue

					exit 1
				} finally {
					if($Extract_Folder_Path){
						Remove-Item -Path $Extract_Folder_Path -Force -Recurse -ErrorAction SilentlyContinue
					}
					Remove-Item -Path ("$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestBIOSVersion).exe") -Force -ErrorAction SilentlyContinue
				}
			}
		} elseif ([System.Version]$LatestBIOSVersion -gt [System.Version]$BIOSVersion -and $Remediate -eq $false) {
			Write-Log -Component $Component -LogText "BIOS update available: $BIOSVersion -> $LatestBIOSVersion"
			exit 1
		} else {
			Write-Log -Component $Component -LogText "BIOS is already up-to-date: $BIOSVersion"
			exit 0
		}
	} else {
		Write-Log -Component $Component -LogText "Lenovo Consumer Hardware" -Type Warning
		
		if([datetime]$LatestLenovoBIOS.ReleaseDate -gt $BIOS_info.ReleaseDate -and $LatestLenovoBIOS.version -ne $BIOS_info.SMBIOSBIOSVersion -and $Remediate -eq $true){
			Write-Log -Component $Component -LogText "Downloading BIOS: $($LatestLenovoBIOS.ReleaseDate)"
			Invoke-WebRequest -Uri ($baseUrl + $PackageXml.Package.Files.Installer.File.Name) -OutFile ("$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestLenovoBIOS.ReleaseDate).exe")
			If(Test-Path ("$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestLenovoBIOS.ReleaseDate).exe")){
				Write-Log -Component $Component -LogText "Updating BIOS: $($BIOS_info.ReleaseDate) -> $($LatestLenovoBIOS.ReleaseDate)"
				
				$Extract_Folder_Path = $null
				try	{
					$Extract_Folder_Path = "$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$(($LatestLenovoBIOS.ReleaseDate))"
					if (!(Test-Path $Extract_Folder_Path)){New-Item -Path $Extract_Folder_Path -ItemType Directory -Force}
					& tar -xf "$($env:windir)\Temp\Lenovo_BIOS_Update_$($LatestLenovoBIOS.ReleaseDate).exe" -C $Extract_Folder_Path
					
					$BiosUpdateFile = Get-ChildItem -Path $Extract_Folder_Path -Filter "*.fd"
					
					if((Test-Path "$Extract_Folder_Path\H2OFFT-W.exe") -and (Test-Path $BiosUpdateFile.FullName)){
						Write-Log -Component $Component -LogText "Disable BitLocker for one reboot"
						#& cmd.exe /c "manage-bde -protectors -disable C:"
						if ((Manage-Bde -Status C:) -match "Protection On") {
							Suspend-BitLocker -MountPoint "$($env:SystemDrive)" -RebootCount 1
						}
						
						$IniPlatform = Get-Content "$Extract_Folder_Path\platform.ini"
						$IniPlatform = $IniPlatform -replace '^Confirm=.*$', 'Confirm=0'
						$IniPlatform = $IniPlatform -replace '^Silent=.*$', 'Silent=1'
						$IniPlatform = $IniPlatform -replace '^SilentWithDialog=.*$', 'SilentWithDialog=0'
						$IniPlatform | Set-Content "$Extract_Folder_Path\platform.ini"
						
						$FlashSwitches = $null
						#$FlashSwitches = "$BiosUpdateFile -s -capsule"
						
						Write-Log -Component $Component -LogText "Tryig to install BIOS Update: $Extract_Folder_Path\H2OFFT-W.exe $FlashSwitches"
						$FlashProcess = Start-Process -FilePath "$Extract_Folder_Path\H2OFFT-W.exe" -WorkingDirectory $Extract_Folder_Path -Passthru -Wait

						Write-Log -Component $Component -LogText "BIOS Update installed with exit code: $($FlashProcess.ExitCode)"
						
						if($FlashProcess.ExitCode -eq 3010) {
							try {   
								Show-ToastMessage
							}
							catch {
								Write-Log -Component $Component -LogText "Toast notification failed: $_" -Type Error
							}
						}
					}
					

				}
				catch {
					Write-Log -Component $Component -LogText "Error during last BIOS action: $_" -Type Error
					
					$BLinfo = Get-Bitlockervolume | Where-Object { $_.MountPoint -eq $env:SystemDrive}
					if($blinfo.ProtectionStatus -ne 'On'){
						Write-Host "Enable Bitlocker"
						Resume-BitLocker -MountPoint ($BLinfo.MountPoint)
					}

					if($Extract_Folder_Path){
						Remove-Item -Path $Extract_Folder_Path -Force -Recurse -ErrorAction SilentlyContinue
					}
					Remove-Item -Path ("$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestLenovoBIOS.ReleaseDate).exe") -Force -ErrorAction SilentlyContinue

					exit 1
				} finally {
					if($Extract_Folder_Path){
						Remove-Item -Path $Extract_Folder_Path -Force -Recurse -ErrorAction SilentlyContinue
					}
					Remove-Item -Path ("$($env:windir)\Temp\" + "Lenovo_BIOS_Update_$($LatestLenovoBIOS.ReleaseDate).exe") -Force -ErrorAction SilentlyContinue
				}
			}
			
		} elseif ([datetime]$LatestLenovoBIOS.ReleaseDate -gt $BIOS_info.ReleaseDate -and $Remediate -eq $false) {
			Write-Log -Component $Component -LogText "BIOS update available: $($BIOS_info.ReleaseDate) -> $($LatestLenovoBIOS.ReleaseDate)"
			exit 1
		} else {
			Write-Log -Component $Component -LogText "BIOS is already up-to-date: $($BIOS_info.ReleaseDate)"
			exit 0
		}
	}
	
} elseif ($Manufacturer -match "Dell"){

    $Component = "DELL BIOS"

    $CabPathIndex = "$($env:windir)\Temp\CatalogIndexPC.cab"
    $CabPathIndexModel = "$env:temp\CatalogIndexModel.cab"
    $DellCabExtractPath = "$($env:windir)\Temp\DellCabExtract"

    if (!(Test-Path $DellCabExtractPath)){New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    Remove-Item -Path $CabPathIndex -Force -ErrorAction SilentlyContinue

    Write-Log -Component $Component -LogText "Downloading CatalogIndexPC.cab" -Type Information
    Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing

    if (Test-Path $CabPathIndex){
        $Expand = expand $CabPathIndex "$DellCabExtractPath\CatalogIndexPC.xml"
        Remove-Item -Path $CabPathIndex -Force -ErrorAction SilentlyContinue

        [xml]$XMLIndex = Get-Content "$DellCabExtractPath\CatalogIndexPC.xml"
    } else {
        Write-Log -Component $Component -LogText "CatalogIndexPC.xml does not exist" -Type Error
		exit 1
    }

    $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber

    $XMLModel = $XMLIndex.ManifestIndex.GroupManifest | Where-Object {$_.SupportedSystems.Brand.Model.systemID -match $SystemSKUNumber}

    if ($XMLModel) {
        Write-Log -Component $Component -LogText "Downloaded Dell DCU XML, now looking for Model Updates" -Type Information
        Invoke-WebRequest -Uri "https://downloads.dell.com/$($XMLModel.ManifestInformation.path)" -OutFile $CabPathIndexModel -UseBasicParsing
        if (Test-Path $CabPathIndexModel){
            $Expand = expand $CabPathIndexModel "$DellCabExtractPath\CatalogIndexPCModel.xml"
            Remove-Item -Path $CabPathIndexModel -Force -ErrorAction SilentlyContinue
        }

        if(Test-Path "$DellCabExtractPath\CatalogIndexPCModel.xml"){
            [xml]$XMLIndexCAB = Get-Content "$DellCabExtractPath\CatalogIndexPCModel.xml"

            $LatestDellBIOS = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object {$_.ComponentType.value -eq "BIOS" -and [datetime]$_.ReleaseDate -le (Get-Date).AddDays(-($LatestBIOSDays))} | Sort-Object { [Version]$_.vendorVersion } -Descending | Select-Object -First 1

            if ([datetime]$LatestDellBIOS.ReleaseDate -gt (Get-Date).AddDays(-($LatestBIOSDays))) {
		        Write-Log -Component $Component -LogText "BIOS update is newer than $($LatestBIOSDays) days. Not installing yet!"
		        exit 0
	        }
	
	        $BIOS_info = get-ciminstance win32_bios | Select-Object *
	        $BIOSVersion = $BIOS_info.SMBIOSBIOSVersion

            if([System.Version]$LatestDellBIOS.vendorVersion -gt [System.Version]$BIOSVersion -and $Remediate -eq $true) {
                
                Invoke-WebRequest -Uri "https://downloads.dell.com/$($LatestDellBIOS.path)" -OutFile ("$($env:windir)\Temp\" + "Dell_BIOS_Update_$($LatestDellBIOS.vendorVersion).exe") -UseBasicParsing

                if(Test-Path ("$($env:windir)\Temp\" + "Dell_BIOS_Update_$($LatestDellBIOS.vendorVersion).exe")){

                    try {
                        Write-Log -Component $Component -LogText "Disable BitLocker for one reboot"
                        #& cmd.exe /c "manage-bde -protectors -disable C:"
                        if ((Manage-Bde -Status C:) -match "Protection On") {
                            Suspend-BitLocker -MountPoint "$($env:SystemDrive)" -RebootCount 1
                        }

                        Write-Log -Component $Component -LogText "Tryig to install BIOS Update: Dell_BIOS_Update_$($LatestDellBIOS.vendorVersion).exe"
                        $FlashProcess = Start-Process -FilePath ("$($env:windir)\Temp\" + "Dell_BIOS_Update_$($LatestDellBIOS.vendorVersion).exe") -ArgumentList "/s" -Wait -PassThru

                        Write-Log -Component $Component -LogText "BIOS Update installed with exit code: $($FlashProcess.ExitCode)"

                        try {   
                            Show-ToastMessage
                        }
                        catch {
                            Write-Log -Component $Component -LogText "Toast notification failed: $_" -Type Error
                        }
                    }
                    catch {
				        Write-Log -Component $Component -LogText "Error during last BIOS action" -Type Error
                
                        $BLinfo = Get-Bitlockervolume | Where-Object { $_.MountPoint -eq $env:SystemDrive}
                        if($blinfo.ProtectionStatus -ne 'On'){
                            Write-Host "Enable Bitlocker"
                            Resume-BitLocker -MountPoint ($BLinfo.MountPoint)
                        }

                        Remove-Item -Path ("$($env:windir)\Temp\" + "Dell_BIOS_Update_$($LatestDellBIOS.vendorVersion).exe") -Force -ErrorAction SilentlyContinue

				        exit 1
                    } finally {
                        Remove-Item -Path ("$($env:windir)\Temp\" + "Dell_BIOS_Update_$($LatestDellBIOS.vendorVersion).exe") -Force -ErrorAction SilentlyContinue
                    }
                }
            }  elseif ([System.Version]$LatestDellBIOS.vendorVersion -gt [System.Version]$BIOSVersion -and $Remediate -eq $false) {
                Write-Log -Component $Component -LogText "BIOS update available: $BIOSVersion -> $LatestDellBIOS.vendorVersion"
                exit 1
            } else {
                Write-Log -Component $Component -LogText "BIOS is already up-to-date: $BIOSVersion"
                exit 0
            }
        } else {
            Write-Log -Component $Component -LogText "Model specific CatalogIndexPCModel.xml does not exist" -Type Error
            exit 1
        }
    } else {
        Write-Log -Component $Component -LogText "No matching model found in Dell CatalogIndexPC.xml for SystemSKUNumber: $SystemSKUNumber" -Type Error
        exit 1
    }

} else {
	$Component = "Manufacturer"
    Write-Log -Component $Component -LogText "Not a HP or Lenovo device: $Manufacturer"
    exit 0
}