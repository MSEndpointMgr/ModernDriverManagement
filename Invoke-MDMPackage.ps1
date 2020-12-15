<#
.SYNOPSIS
Download MDM driver package (regular package) matching computer model, manufacturer and operating system.
.DESCRIPTION
This script will determine the manufacturer, model/type, architecture and operating system being deployed to query
the AdminService endpoint (or XML file) for a list of packages. It then sets the OSDDownloadDownloadPackages variable
to include the PackageID property of the package(s) matching the computer specs.
.PARAMETER DeploymentType
Set the script to operate in deployment type mode: BareMetal (default), OSUpdate, DriverUpdate or PreCache.
.PARAMETER Endpoint
Specify the fully qualified domain name of the server hosting the AdminService, e.g. CM01.domain.local.
.PARAMETER UserName
Specify the service account user name used for authenticating against the AdminService endpoint.
.PARAMETER Password
Specify the service account password used for authenticating against the AdminService endpoint.
.PARAMETER TargetOSVersion
Define the value that will be used as the target operating system version e.g. '2004'.
.PARAMETER OSVersionFallback
Use this switch to check for drivers packages that matches earlier versions of Windows than what's specified as input for TargetOSVersion.
.PARAMETER OSArchitecture
Define the value that will be used as the target operating system architecture e.g. 'x64'.
.PARAMETER Manufacturer
Override the automatically detected computer manufacturer when running in debug mode.
.PARAMETER ComputerModel
Override the automatically detected computer model when running in debug mode.
.PARAMETER SystemSKU
Override the automatically detected SystemSKU when running in debug mode.
.PARAMETER Filter
Define a filter used when calling ConfigMgr WebService to only return objects matching the filter.
.PARAMETER OperationalMode
Define the operational mode, either Production (default) or Pilot, for when calling ConfigMgr WebService to only return objects matching the selected operational mode.
.PARAMETER DriverInstallMode
Specify to install drivers using DISM.exe with recurse option (default) or spawn a new process for each driver.
.PARAMETER DriverSelection
Specify to download drivers using an XML file or the Admin service (default) as query source.
.PARAMETER UseDriverFallback
Activate search for a driver fallback package if SystemSKU or computer model does not return exact results.
.PARAMETER PreCachePath
Specify a custom path for the PreCache directory, overriding the default CCMCache directory, fallback is temp folder.
.PARAMETER DebugMode
Set the script to operate in 'DebugMode', hence no actual installation of drivers.
.PARAMETER XMLFileName
Option to override (default) name of the XML selection file: DriverPackages.xml
.PARAMETER LogFileName
Option to override (default) name of the script output logfile: ApplyDriverPackage.log
.EXAMPLE
# Detect, download and apply drivers during OS deployment with ConfigMgr:
.\Invoke-MDMPackage.ps1 -Endpoint "CM01.domain.com" -TargetOSVersion 1909
# Detect, download and apply drivers during OS deployment with ConfigMgr and use a driver fallback package if no matching driver package can be found:
.\Invoke-MDMPackage.ps1 -Endpoint "CM01.domain.com" -TargetOSVersion 1909 -UseDriverFallback
# Detect, download and apply drivers during OS deployment with ConfigMgr and check for driver packages that matches an earlier version than what's specified for TargetOSVersion:
.\Invoke-MDMPackage.ps1 -DeploymentType BareMetal -Endpoint "CM01.domain.com" -TargetOSVersion 1909 -OSVersionFallback
# Detect and download drivers during OS upgrade with ConfigMgr:
.\Invoke-MDMPackage.ps1 -DeploymentType OSUpgrade -Endpoint "CM01.domain.com" -TargetOSVersion 1909
# Detect, download and update a device with latest drivers for an running operating system using ConfigMgr:
.\Invoke-MDMPackage.ps1 -DeploymentType DriverUpdate -Endpoint "CM01.domain.com"
# Detect and download (pre-caching content) during OS upgrade with ConfigMgr:
.\Invoke-MDMPackage.ps1 -DeploymentType PreCache -Endpoint "CM01.domain.com" -TargetOSVersion 1909
# Detect and download (pre-caching content) to a custom path during OS upgrade with ConfigMgr:
.\Invoke-MDMPackage.ps1 -DeploymentType PreCache -Endpoint "CM01.domain.com" -TargetOSVersion 1909 -PreCachePath "$($env:SystemDrive)\MDMDrivers"
# Run in a debug mode for testing purposes on the targeted computer model:
.\Invoke-MDMPackage.ps1 -DebugMode -Endpoint "CM01.domain.com" -UserName "svc@domain.com" -Password "svc-password" -TargetOSVersion 2004
# Run in a debug mode for testing purposes and overriding the (automatically detected) computer specifications:
.\Invoke-MDMPackage.ps1 -DebugMode -Endpoint "CM01.domain.com" -UserName "svc@domain.com" -Password "svc-password" -TargetOSVersion 1909 -Manufacturer "Lenovo" -ComputerModel "Thinkpad X1 Tablet" -SystemSKU "20KKS7"
# Detect, download and apply drivers during OS deployment with ConfigMgr and use an XML table as the source of driver package details instead of the AdminService:
.\Invoke-MDMPackage.ps1 -TargetOSVersion "1909" -OSVersionFallback "1903" -DriverSelection XML -XMLFileName "Install32bitDrivers.xml"
.NOTES
FileName:	Invoke-MDMPackage.ps1
CoAuthor:	Chris Kenis
Contact: 	@KICTS
Created: 	2020-12-01
Contributors:
Version history:
4.0.8.1 - (2020-12-08) - Alternative version with some code shuffling and rewrite of functions retaining expected output
4.0.8.2 - (2020-12-15) - Forked version of Invoke-MDMPackage with major rewrite of code maintaining expected functionality
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
	[parameter(HelpMessage = "Specify the deployment type mode for driver package deployments, e.g. 'BareMetal' (= default), 'OSUpdate', 'DriverUpdate', 'PreCache'.")]
	[ValidateSet("BareMetal", "OSUpdate", "DriverUpdate", "PreCache")]
	[string]$DeploymentType = "BareMetal",
	[parameter(HelpMessage = "Specify the fully qualified domain name of the server hosting the AdminService, e.g. CM01.domain.local.")]
	[string]$Endpoint,
	[parameter(ParameterSetName = "Debug", HelpMessage = "Specify the service account user name used for authenticating against the AdminService endpoint.")]
	[string]$UserName,
	[parameter(ParameterSetName = "Debug", HelpMessage = "Specify the service account password used for authenticating against the AdminService endpoint.")]
	[string]$Password,
	[parameter(HelpMessage = "Override the automatically detected (shorthand) OS version, e.g. 2004")]
	[ValidateScript( { $OsBuildVersions.ContainsValue($_) })]
	[string]$OSVersion,
	[parameter(HelpMessage = "Use this switch to check for driver packages that match a previous version of Windows.")]
	[switch]$OSVersionFallback,
	[parameter(HelpMessage = "Define the value that will be used as the target operating system architecture e.g. 'x64'.")]
	[ValidateSet("x64", "x86")]
	[string]$OSArchitecture,
	[parameter(HelpMessage = "Override the automatically detected computer manufacturer.")]
	[string]$Manufacturer,
	[parameter(HelpMessage = "Override the automatically detected computer model.")]
	[string]$ComputerModel,
	[parameter(HelpMessage = "Override the automatically detected SystemSKU (manufacterer's model/type code).")]
	[string]$SystemSKU,
	[parameter(HelpMessage = "Define a filter to only return matched objects when querying AdminService.")]
	[ValidateNotNullOrEmpty()]
	[string]$Filter = "Drivers",
	[parameter(HelpMessage = "Set operational mode to: Production - Pilot, when querying packages from ConfigMgr WebService.")]
	[ValidateSet("Production", "Pilot")]
	[string]$OperationalMode = "Production",
	[parameter(HelpMessage = "Specify whether to install drivers using DISM.exe with recurse(= default) option or spawn a new process for each driver.")]
	[ValidateSet("Single", "Recurse")]
	[string]$DriverInstallMode = "Recurse",
	[parameter(HelpMessage = "Specify the source to query for selection of driver(s) to apply: XML or AdminService (= default)")]
	[ValidateSet("XML", "AdminService")]
	[string]$DriverSelection = "AdminService",
	[parameter(HelpMessage = "Enable search for driver fallback package(s) when none are returned based on computer details.")]
	[switch]$UseDriverFallback,
	[parameter(HelpMessage = "Specify a custom path for the PreCache directory, overriding the default CCMCache directory.")]
	[string]$PreCachePath,
	[parameter(HelpMessage = "Set the script to operate in 'DebugMode' deployment type mode, drivers will not be downloaded nor installed.")]
	[switch]$DebugMode,
	[parameter(HelpMessage = "Name of the XML file specifying the driver package(s) to apply.")]
	[string]$XMLFileName = "DriverPackages.xml",
	[parameter(HelpMessage = "Name of the log file for script output.")]
	[string]$LogFileName = "ApplyDriverPackage.log"
)

Process {
	Write-CMLogEntry -Value "[ApplyDriverPackage]: Apply Driver Package script version $($ScriptVersion) initiated in $($DeploymentType) deployment mode"
	Write-CMLogEntry -Value " - Apply driver package in $($OperationalMode) mode"
	try {
		# Determine computer OS version, Architecture, Manufacturer, Model, SystemSKU and FallbackSKU
		$ComputerData = Get-ComputerData
		Write-CMLogEntry -Value "[DriverPackage]: Starting driver package retrieval using $($DriverSelection) as query source."
		# Construct array list for matched drivers packages
		$script:DriverPackageList = New-Object -TypeName "System.Collections.ArrayList"
		#Resolve, validate, test and authenticate the Admin webservice
		$AdminService = Get-AdminService
		switch ($DriverSelection) {
			"XML" {
				# Define the path for the pre-downloaded XML Package Logic file
				$XMLPackageLogicFile = Join-Path -Path $Script:TSEnvironment.Value("MDMXMLPackage01") -ChildPath $XMLFileName
				if (Test-Path -Path $XMLPackageLogicFile) { $DriverPackageList = Get-DriverPackages -ComputerData $ComputerData -XMLFilePath $XMLPackageLogicFile }
				else { New-ErrorRecord -Message " - Failed to locate required $($XMLFileName) logic file for XMLPackage deployment type, ensure it has been pre-downloaded in a Download Package Content step before running this script" -ThrowError }
			}
			"AdminService" {
				# Retrieve available driver packages from web service
				$DriverPackageList = Get-DriverPackages -ComputerData $ComputerData -FallBack:$UseDriverFallback -AdminService $AdminService -UrlResource "/SMS_Package?`$filter=contains(Name,'$($Filter)')"
			}
		}#switch
		# At this point, the code below here is not allowed to be executed in debug mode, as it requires access to the Microsoft.SMS.TSEnvironment COM object
		if (-not $DebugMode.IsPresent) {
			# Attempt to download the matched driver package content files from distribution point
			$DriverPackageContentLocation = Invoke-DownloadDriverPackageContent -Package $DriverPackageList[0]
			# Depending on deployment type, take action accordingly when applying the driver package files
			Install-DriverPackageContent -ContentLocation $DriverPackageContentLocation
			Write-CMLogEntry -Value "[DriverPackageInstall]: Completed driver package install phase"
		}
	}
	catch [System.Exception] {
		New-ErrorRecord -Message "[ApplyDriverPackage]: Apply Driver Package process failed, please refer to previous error or warning messages"
		# Main try-catch block was triggered, this should cause the script to fail with exit code 1
		exit 1
	}
}#process

Begin {
	[version]$ScriptVersion = "4.0.8.1"
	# Set script error preference variable
	$ErrorActionPreference = "Stop"
	$LogsDirectory = Join-Path -Path $env:SystemRoot -ChildPath "Temp"
	[bool]$script:RunInTS = $false
	try {
		$Script:TSEnvironment = New-Object -ComObject "Microsoft.SMS.TSEnvironment" -ErrorAction Stop
		$LogsDirectory = $Script:TSEnvironment.Value("_SMSTSLogPath")
		$script:RunInTS = $true
	}
	catch [System.Exception] { Write-Warning -Message "Script is not running in a Task Sequence" }
	$LogFilePath = Join-Path -Path $LogsDirectory -ChildPath $LogFileName
	[System.Collections.ArrayList]$script:LogEntries = @()
	[System.Collections.Hashtable]$script:OsBuildVersions = @{
		"19042" = '2009'
		"19041" = '2004'
		"18363" = '1909'
		"18362" = '1903'
		"17763" = '1809'
		"17134" = '1803'
		"16299" = '1709'
		"15063" = '1703'
		"14393" = '1607'
	}

	# Functions
	function Write-CMLogEntry {
		param (
			[parameter(Mandatory, HelpMessage = "Value added to the log file.")]
			[ValidateNotNullOrEmpty()]
			[string]$Value,
			[parameter(HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
			[ValidateNotNullOrEmpty()]
			[ValidateSet("1", "2", "3")]
			[int]$Severity = 1
		)
		# Construct time stamp for log entry
		if (-not(Test-Path -Path 'variable:global:TimezoneBias')) {
			[string]$global:TimezoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
			if ($TimezoneBias -match "^-") { $TimezoneBias = $TimezoneBias.Replace('-', '+') }
			else { $TimezoneBias = '-' + $TimezoneBias }
		}
		$Time = -join @((Get-Date -Format "HH:mm:ss.fff"), $TimezoneBias)
		# Construct date for log entry
		$Date = (Get-Date -Format "MM-dd-yyyy")
		# Construct context for log entry
		$Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
		# Construct final log entry
		$script:LogEntries.Add("<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""ApplyDriverPackage"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">") | Out-Null
		Write-Verbose -Message $script:LogEntries[-1]
	}
	function New-ErrorRecord {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the exception message details.")]
			[ValidateNotNullOrEmpty()]
			[string]$Message,
			[parameter(HelpMessage = "Specify the violation exception causing the error.")]
			[ValidateNotNullOrEmpty()]
			[string]$Exception = "System.Management.Automation.RuntimeException",
			[parameter(HelpMessage = "Specify the error category of the exception causing the error.")]
			[ValidateNotNullOrEmpty()]
			[System.Management.Automation.ErrorCategory]$ErrorCategory = [System.Management.Automation.ErrorCategory]::NotImplemented,
			[parameter(HelpMessage = "Specify the target object causing the error.")]
			[string]$TargetObject = ([string]::Empty),
			[parameter(HelpMessage = "Throws Error when set to true.")]
			[switch]$ThrowError
		)
		Write-CMLogEntry -Value $Message -Severity 3
		# Construct new error record to be returned from function based on parameter inputs
		$SystemException = New-Object -TypeName $Exception -ArgumentList ([string]::Empty)
		$ErrorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList @($SystemException, $ErrorID, $ErrorCategory, $TargetObject)
		if ($ThrowError.IsPresent) { $PSCmdlet.ThrowTerminatingError($ErrorRecord) }
		# Handle return value
		return $ErrorRecord
	}
	function Invoke-Executable {
		param (
			[parameter(Mandatory, HelpMessage = "Specify the file name or path of the executable to be invoked, including the extension")]
			[ValidateNotNullOrEmpty()]
			[string]$FilePath,
			[parameter(HelpMessage = "Specify arguments that will be passed to the executable")]
			[ValidateNotNull()]
			[string]$Arguments
		)
		# Construct a hash-table for default parameter splatting
		$SplatArgs = @{
			FilePath    = $FilePath
			NoNewWindow = $true
			Passthru    = $true
			ErrorAction = "Stop"
		}
		# Add ArgumentList param if present
		if (-not ([System.String]::IsNullOrEmpty($Arguments))) { $SplatArgs.Add("ArgumentList", $Arguments) }
		# Invoke executable and wait for process to exit
		try {
			$Invocation = Start-Process @SplatArgs
			$Handle = $Invocation.Handle
			$Invocation.WaitForExit()
		}
		catch [System.Exception] { Write-Warning -Message $_.Exception.Message; break }
		return $Invocation.ExitCode
	}
	function Set-MDMTaskSequenceVariable {
		param(
			[parameter(Mandatory)][string]$TSVariable,
			$TsValue = [string]::Empty
		)
		$Script:TSEnvironment.Value($TSVariable) = $TsValue
		if ([string]::IsNullOrEmpty($TsValue)) { $TsValue = "<blank>" }
		Write-CMLogEntry -Value " - Setting task sequence variable $($TSVariable) to: $($TsValue) "
	}
	function ConvertTo-ObfuscatedString {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the string to be obfuscated for log output.")]
			[ValidateNotNullOrEmpty()]
			[string]$InputObject
		)
		# Convert input object to a character array
		$StringArray = $InputObject.ToCharArray()
		# Loop through each character, obfuscate every second item, with exceptions of the @ and period character if present
		for ($i = 1; $i -lt $StringArray.Count; $i++) { $StringArray[$i] = $StringArray[$i] -replace "[^@\.]", "*"; $i++ }
		# Join character array and return value
		return -join @($StringArray)
	}
	function Get-AdminService {
		Write-CMLogEntry -Value "[AdminService]: Starting AdminService endpoint phase"
		# Validate correct value have been either set as a TS environment variable or passed as parameter input for service account user name used to authenticate against the AdminService
		if (-not ($PSBoundParameters.ContainsKey('UserName'))) {
			try {
				# Attempt to read TSEnvironment variable MDMUserName, terminating error is thrown when empty string is parsed to obfuscate function
				$UserName = $Script:TSEnvironment.Value("MDMUserName")
				$ObfuscatedUserName = ConvertTo-ObfuscatedString -InputObject $UserName
				Write-CMLogEntry -Value " - Successfully read service account username: $($ObfuscatedUserName)"
			}
			catch {
				if ($DebugMode.IsPresent) { New-ErrorRecord -Message " - Service account username could not be determined from parameter input" -ThrowError }
				New-ErrorRecord -Message " - Required service account password could not be determined from TS environment variable" -ThrowError
			}
		}
		if (-not ($PSBoundParameters.ContainsKey('Password'))) {
			try {
				$Password = $Script:TSEnvironment.Value("MDMPassword")
				$ObfuscatedPassword = ConvertTo-ObfuscatedString -InputObject $Password
				if ($DebugMode.IsPresent) { Write-CMLogEntry -Value " - Successfully read service account password: $($ObfuscatedPassword)" }
				else { Write-CMLogEntry -Value " - Successfully read service account password: ********" }
			}
			catch {
				if ($DebugMode.IsPresent) { New-ErrorRecord -Message " - Service account password could not be determined from parameter input" -ThrowError }
				New-ErrorRecord -Message " - Required service account password could not be determined from TS environment variable" -ThrowError
			}
		}
		# Construct PSCredential object for AdminService authentication, this is required for both endpoint types
		$Credential = Get-AuthCredential -UserName $UserName -Password $Password
		$AdminServiceEndpoint = Get-AdminServiceEndpoint
		# Attempt to retrieve an authentication token for external AdminService endpoint connectivity
		# This will only execute when the endpoint type has been detected as External, which means that authentication is needed against the Cloud Management Gateway
		if ($AdminServiceEndpoint.Type -like "External") {
			Get-AuthToken -TenantName $AdminServiceEndpoint.TenantName -ClientID $AdminServiceEndpoint.ClientID -Credential $Credential
		}
		Write-CMLogEntry -Value "[AdminService]: Completed AdminService endpoint phase"
		return $AdminServiceEndpoint
	}
	function Get-AdminServiceEndpoint {
		$AdminServiceEndpointType = "Internal"
		switch ($DeploymentType) {
			"BareMetal" {
				$SMSInWinPE = $Script:TSEnvironment.Value("_SMSTSInWinPE")
				if ($SMSInWinPE -eq $true) { Write-CMLogEntry -Value " - Script is running within a task sequence in WinPE phase, automatically configuring AdminService endpoint type" }
				else { New-ErrorRecord -Message " - Script is not running in WinPE during $($DeploymentType) deployment type, this is not a supported scenario" -ThrowError }
			}
			"OSUpdate" {}
			"DriverUpdate" {}
			"PreCache" {}
			default {
				Write-CMLogEntry -Value " - Attempting to determine AdminService endpoint type based on current active Management Point candidates and from ClientInfo class"
				# Determine active MP candidates
				$ActiveMPCandidates = Get-WmiObject -Namespace "root\ccm\LocationServices" -Class "SMS_ActiveMPCandidate"
				[byte]$ActiveMPInternalCandidatesCount = ($ActiveMPCandidates | Where-Object { $PSItem.Type -like "Assigned" } | Measure-Object).Count
				[byte]$ActiveMPExternalCandidatesCount = ($ActiveMPCandidates | Where-Object { $PSItem.Type -like "Internet" } | Measure-Object).Count
				# Determine if ConfigMgr client has detected if the computer is currently on internet or intranet
				$CMClientInfo = Get-WmiObject -Namespace "root\ccm" -Class "ClientInfo"
				switch ($CMClientInfo.InInternet) {
					$true {
						if ($ActiveMPExternalCandidatesCount -ge 1) {
							# Attempt to read TSEnvironment variable MDMExternalEndpoint
							$ExternalEndpoint = $Script:TSEnvironment.Value("MDMExternalEndpoint")
							if (-not([string]::IsNullOrEmpty($ExternalEndpoint))) {
								Write-CMLogEntry -Value " - Successfully read external endpoint address for AdminService through CMG from TS environment variable 'MDMExternalEndpoint': $($ExternalEndpoint)"
							}
							else { New-ErrorRecord -Message " - Required external endpoint address for AdminService through CMG could not be determined from TS environment variable" -ThrowError }
							# Attempt to read TSEnvironment variable MDMClientID
							$ClientID = $Script:TSEnvironment.Value("MDMClientID")
							if (-not([string]::IsNullOrEmpty($ClientID))) {
								Write-CMLogEntry -Value " - Successfully read client identification for AdminService through CMG from TS environment variable 'MDMClientID': $($ClientID)"
							}
							else { New-ErrorRecord -Message " - Required client identification for AdminService through CMG could not be determined from TS environment variable" -ThrowError }
							# Attempt to read TSEnvironment variable MDMTenantName
							$TenantName = $Script:TSEnvironment.Value("MDMTenantName")
							if (-not([string]::IsNullOrEmpty($TenantName))) {
								Write-CMLogEntry -Value " - Successfully read client identification for AdminService through CMG from TS environment variable 'MDMTenantName': $($TenantName)"
							}
							else { New-ErrorRecord -Message " - Required client identification for AdminService through CMG could not be determined from TS environment variable" -ThrowError }
							$AdminServiceEndpointType = "External"
						}
						else { New-ErrorRecord -Message " - Detected as an Internet client but unable to acquire External AdminService endpoint, bailing out" -ThrowError }
					}
					$false {
						if ($ActiveMPInternalCandidatesCount -lt 1) { New-ErrorRecord -Message " - Detected as an Intranet client but unable to acquire Internal AdminService endpoint, bailing out" -ThrowError }
					}
				}#switch
			}
		}#switch
		switch ($AdminServiceEndpointType) {
			"Internal" {
				#if (-not $PSBoundParameters.Contains("Endpoint")){ $Endpoint = (Get-WmiObject -Namespace "root\SMS" -Class SMS_ProviderLocation).Machine }
				$AdminServiceURL = "https://{0}/AdminService/wmi" -f $Endpoint
			}
			"External" { $AdminServiceURL = "{0}/wmi" -f $ExternalEndpoint }
		}
		Write-CMLogEntry -Value " - AdminService endpoint type is: $($AdminServiceEndpointType) and can be reached via URL: $($AdminServiceURL)"
		$AdminServiceEndpoint = [PSCustomObject]@{
			URL        = $AdminServiceURL
			Type       = $AdminServiceEndpointType
			ClientID   = $ClientID
			TenantName = $TenantName
		}
		return $AdminServiceEndpoint
	}
	function Install-AuthModule {
		param( $ModuleName = "PSIntuneAuth" )
		# Determine if the PSIntuneAuth module needs to be installed
		try {
			Write-CMLogEntry -Value " - Attempting to locate $($ModuleName) module"
			$PSIntuneAuthModule = Get-InstalledModule -Name $ModuleName -ErrorAction Stop -Verbose:$false
			if ($null -ne $PSIntuneAuthModule) {
				Write-CMLogEntry -Value " - Authentication module detected, checking for latest version"
				$LatestModuleVersion = (Find-Module -Name $ModuleName -ErrorAction SilentlyContinue -Verbose:$false).Version
				if ($LatestModuleVersion -gt $PSIntuneAuthModule.Version) {
					Write-CMLogEntry -Value " - Latest version of $($ModuleName) module is not installed, attempting to install: $($LatestModuleVersion.ToString())"
					$UpdateModuleInvocation = Update-Module -Name $ModuleName -Scope CurrentUser -Force -ErrorAction Stop -Confirm:$false -Verbose:$false
				}
			}
		}
		catch [System.Exception] {
			Write-CMLogEntry -Value " - Unable to detect $($ModuleName) module, attempting to install from PSGallery" -Severity 2
			try {
				Install-PackageProvider -Name "NuGet" -Force -Verbose:$false
				Install-Module -Name $ModuleName -Scope AllUsers -Force -ErrorAction Stop -Confirm:$false -Verbose:$false
				Write-CMLogEntry -Value " - Successfully installed $($ModuleName) module"
			}
			catch [System.Exception] {
				New-ErrorRecord -Message " - An error occurred while attempting to install $($ModuleName) module. Error message: $($_.Exception.Message)" -ThrowError
			}
		}
	}
	function Get-AuthToken {
		param(
			[string]$TenantName,
			[string]$ClientID,
			[System.Management.Automation.PSCredential]$Credential
		)
		try {
			# Attempt to install PSIntuneAuth module, if already installed ensure the latest version is being used
			Install-AuthModule
			# Retrieve authentication token
			Write-CMLogEntry -Value " - Attempting to retrieve authentication token using native client with ID: $($ClientID)"
			$AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName -ClientID $ClientID -Credential $Credential -Resource "https://ConfigMgrService" -RedirectUri "https://login.microsoftonline.com/common/oauth2/nativeclient" -ErrorAction Stop
			Write-CMLogEntry -Value " - Successfully retrieved authentication token"
			return $AuthToken
		}
		catch [System.Exception] { New-ErrorRecord -Message " - Failed to retrieve authentication token. Error message: $($PSItem.Exception.Message)" -ThrowError }
	}
	function Get-AuthCredential {
		[OutputType([System.Management.Automation.PSCredential])]
		param($UserName, $Password)
		# Construct PSCredential object for authentication
		$EncryptedPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
		$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @($UserName, $EncryptedPassword)
		return $Credential
	}
	function Get-AdminServiceItem {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the resource for the AdminService API call, e.g. '/SMS_Package'.")]
			[ValidateNotNullOrEmpty()]
			[string]$Resource,
			[PSCustomObject]$AdminServiceEndpoint
		)
		$AdminServiceUri = $AdminServiceEndpoint.URL + $Resource
		Write-CMLogEntry -Value " - Calling AdminService endpoint with URI: $($AdminServiceUri)"
		switch ($AdminServiceEndpoint.Type) {
			"External" {
				try { $AdminServiceResponse = Invoke-RestMethod -Method Get -Uri $AdminServiceUri -Headers $AuthToken -ErrorAction Stop }
				catch [System.Exception] { New-ErrorRecord -Message " - Failed to retrieve available package items from AdminService endpoint. Error message: $($PSItem.Exception.Message)" -ThrowError }
			}
			"Internal" {
				try { $AdminServiceResponse = Invoke-RestMethod -Method Get -Uri $AdminServiceUri -Credential $Credential -ErrorAction Stop	}
				catch [System.Security.Authentication.AuthenticationException] {
					Write-CMLogEntry -Value " - The remote AdminService endpoint certificate is invalid according to the validation procedure. Error message: $($PSItem.Exception.Message)" -Severity 2
					Write-CMLogEntry -Value " - Will attempt to set the current session to ignore self-signed certificates and retry AdminService endpoint connection" -Severity 2
					# Convert encoded base64 string for ignore self-signed certificate validation functionality
					$CertificationValidationCallbackEncoded = "DQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAdQBzAGkAbgBnACAAUwB5AHMAdABlAG0AOwANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAB1AHMAaQBuAGcAIABTAHkAcwB0AGUAbQAuAE4AZQB0ADsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAdQBzAGkAbgBnACAAUwB5AHMAdABlAG0ALgBOAGUAdAAuAFMAZQBjAHUAcgBpAHQAeQA7AA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHUAcwBpAG4AZwAgAFMAeQBzAHQAZQBtAC4AUwBlAGMAdQByAGkAdAB5AC4AQwByAHkAcAB0AG8AZwByAGEAcABoAHkALgBYADUAMAA5AEMAZQByAHQAaQBmAGkAYwBhAHQAZQBzADsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAcAB1AGIAbABpAGMAIABjAGwAYQBzAHMAIABTAGUAcgB2AGUAcgBDAGUAcgB0AGkAZgBpAGMAYQB0AGUAVgBhAGwAaQBkAGEAdABpAG8AbgBDAGEAbABsAGIAYQBjAGsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAewANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHAAdQBiAGwAaQBjACAAcwB0AGEAdABpAGMAIAB2AG8AaQBkACAASQBnAG4AbwByAGUAKAApAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAewANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAaQBmACgAUwBlAHIAdgBpAGMAZQBQAG8AaQBuAHQATQBhAG4AYQBnAGUAcgAuAFMAZQByAHYAZQByAEMAZQByAHQAaQBmAGkAYwBhAHQAZQBWAGEAbABpAGQAYQB0AGkAbwBuAEMAYQBsAGwAYgBhAGMAawAgAD0APQBuAHUAbABsACkADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAUwBlAHIAdgBpAGMAZQBQAG8AaQBuAHQATQBhAG4AYQBnAGUAcgAuAFMAZQByAHYAZQByAEMAZQByAHQAaQBmAGkAYwBhAHQAZQBWAGEAbABpAGQAYQB0AGkAbwBuAEMAYQBsAGwAYgBhAGMAawAgACsAPQAgAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAZABlAGwAZQBnAGEAdABlAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAKAANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAATwBiAGoAZQBjAHQAIABvAGIAagAsACAADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAFgANQAwADkAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBlAHIAdABpAGYAaQBjAGEAdABlACwAIAANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAWAA1ADAAOQBDAGgAYQBpAG4AIABjAGgAYQBpAG4ALAAgAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABTAHMAbABQAG8AbABpAGMAeQBFAHIAcgBvAHIAcwAgAGUAcgByAG8AcgBzAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAKQANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHIAZQB0AHUAcgBuACAAdAByAHUAZQA7AA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAfQA7AA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAB9AA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAfQANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAB9AA0ACgAgACAAIAAgACAAIAAgACAA"
					$CertificationValidationCallback = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($CertificationValidationCallbackEncoded))
					# Load required type definition to be able to ignore self-signed certificate to circumvent issues with AdminService running with ConfigMgr self-signed certificate binding
					Add-Type -TypeDefinition $CertificationValidationCallback
					[ServerCertificateValidationCallback]::Ignore()
					try {
						# Call AdminService endpoint to retrieve package data
						$AdminServiceResponse = Invoke-RestMethod -Method Get -Uri $AdminServiceUri -Credential $Credential -ErrorAction Stop
					}
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to retrieve available package items from AdminService endpoint. Error message: $($PSItem.Exception.Message)" -ThrowError }
				}
			}
		}
		# Add returned driver package objects to array list
		if ($null -ne $AdminServiceResponse.value) {
			# Construct array object to hold return value
			$PackageArray = New-Object -TypeName System.Collections.ArrayList
			foreach ($Package in $AdminServiceResponse.value) { $PackageArray.Add($Package) | Out-Null }
			return $PackageArray
		}
		else { return $null }
	}
	function Get-ComputerData {
		Write-CMLogEntry -Value "[PrerequisiteChecker]: Starting environment prerequisite checker"
		# Gather computer details based upon specific computer Manufacturer
		$NameSpace = "root\wmi"
		$ModelClass = "Win32_ComputerSystem"
		$ModelProp = "Model"
		$SkuClass = "MS_SystemInformation"
		$SkuProp = "BaseBoardProduct"
		$FallbackSKU = "None"
		if (-not ($PSBoundParameters.ContainsKey('Manufacturer'))) {
			$Manufacturer = (Get-WmiObject -Namespace $NameSpace -Class $ModelClass | Select-Object -ExpandProperty Manufacturer).Trim()
		}
		switch -Wildcard ($Manufacturer) {
			"*Microsoft*" {
				$Manufacturer = "Microsoft"
				$SkuProp = "SystemSKU"
			}
			"*HP*" {
				$Manufacturer = "HP"
			}
			"*Hewlett-Packard*" {
				$Manufacturer = "HP"
			}
			"*Dell*" {
				$Manufacturer = "Dell"
				$SkuProp = "SystemSKU"
				[string]$OEMString = Get-WmiObject -Namespace $NameSpace -Class $ModelClass | Select-Object -ExpandProperty OEMStringArray
				$FallbackSKU = [regex]::Matches($OEMString, '\[\S*]')[0].Value.TrimStart("[").TrimEnd("]")
			}
			"*Lenovo*" {
				$Manufacturer = "Lenovo"
				$ModelClass = "Win32_ComputerSystemProduct"
				$ModelProp = "Version"
				$SkuClass = "Win32_ComputerSystem"
				$SkuProp = "Model"
			}
			"*Panasonic*" {
				$Manufacturer = "Panasonic Corporation"
			}
			"*Viglen*" {
				$Manufacturer = "Viglen"
				$SkuClass = "Win32_BaseBoard"
				$SkuProp = "SKU"
			}
			"*AZW*" {
				$Manufacturer = "AZW"
			}
			"*Fujitsu*" {
				$Manufacturer = "Fujitsu"
				$SkuClass = "Win32_BaseBoard"
				$SkuProp = "SKU"
			}
			"VMWare" {}
			"VirtualBox" {}
			"HyperV" {}
			default { if (-not $DebugMode.IsPresent) { New-ErrorRecord -Message ([string]::Empty) -ThrowError } }
		}
		#if not explicitly defined via param then set computer data value(s)
		if (-not ($PSBoundParameters.ContainsKey('ComputerModel'))) {
			$ComputerModel = (Get-CimInstance -Namespace $NameSpace -ClassName $ModelClass | Select-Object -ExpandProperty $ModelProp).Trim()
		}
		if (-not ($PSBoundParameters.ContainsKey('SystemSKU'))) {
			$SystemSKU = (Get-CimInstance -Namespace $NameSpace -ClassName $SkuClass | Select-Object -ExpandProperty $SkuProp).Trim()
			if ($Manufacturer -eq "Lenovo") { $SystemSKU = $SystemSKU.Substring(0, 4) }
		}
		if (-not ($PSBoundParameters.ContainsKey('OSVersion'))) {
			[System.Version]$OSBuild = (Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Version)
			$OSVersion = $script:OsBuildVersions[$($OSBuild.Build).ToString()]
		}
		if (-not ($PSBoundParameters.ContainsKey('OSArchitecture'))) {
			$Architecture = (Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty OSArchitecture)
			$OSArchitecture = switch -Wildcard ($Architecture) {
				"9" { "x64" }
				"0" { "x86" }
				"64*" { "x64" }
				"32*" { "x86" }
				default {
					New-ErrorRecord -Message " - Unable to translate OS architecture using input object: $($Architecture)" -ThrowError
					return "N/A"
				}
			}
		}
		if (-not ($PSBoundParameters.ContainsKey('OSVersionFallback')) -and $UseDriverFallback.IsPresent) {
			#filter hashtable where buildnumbers are less than OSversion and select value from last entry to return the latest previous buildnumber
			$OSVersionFallback = $script:OsBuildVersions.GetEnumerator() | Sort-Object Name | Where-Object { $_.Value -lt $OSVersion } | Select-Object -Last 1 -ExpandProperty Value
		}
		# Handle output to log file for computer details
		Write-CMLogEntry -Value " - Computer manufacturer determined as: $($Manufacturer)"
		Write-CMLogEntry -Value " - Computer model determined as: $($ComputerModel)"
		Write-CMLogEntry -Value " - Computer SystemSKU determined as: $($SystemSKU)"
		Write-CMLogEntry -Value " - Computer Fallback SystemSKU determined as: $($FallBackSKU)"
		Write-CMLogEntry -Value " - Target operating system name configured as: $($OSName)"
		Write-CMLogEntry -Value " - Target operating system architecture configured as: $($OSArchitecture)"
		Write-CMLogEntry -Value " - Target operating system version configured as: $($OSVersion)"
		# Create a custom object for computer details gathered from local WMI
		$ComputerDetails = [PSCustomObject]@{
			OSName            = "Windows 10"
			OSVersion         = $OSVersion
			FallBackOSVersion = $OSVersionFallback
			Architecture      = $OSArchitecture
			Manufacturer      = $Manufacturer
			Model             = $ComputerModel
			SystemSKU         = $SystemSKU
			FallbackSKU       = $FallBackSKU
		}
		Write-CMLogEntry -Value "[PrerequisiteChecker]: Completed environment prerequisite checker"
		# Handle return value from function
		return $ComputerDetails
	}
	function Get-DriverPackages {
		[CmdletBinding(DefaultParameterSetName = "AdminService")]
		param(
			[PSCustomObject]$ComputerData,
			[parameter(Mandatory, ParameterSetName = "AdminService")]
			[switch]$FallBack,
			[parameter(Mandatory, ParameterSetName = "AdminService")]
			[pscustomobject]$AdminService,
			[parameter(Mandatory, ParameterSetName = "AdminService")]
			[pscustomobject]$UrlResource,
			[parameter(Mandatory, ParameterSetName = "XML")]
			[System.IO.FileInfo]$XMLFilePath
		)
		try {
			switch ($PSCmdLet.ParameterSetName) {
				"XML" {
					Write-CMLogEntry -Value " - Reading XML content logic file driver package entries"
					$Packages = @((([xml]$(Get-Content -Path $XMLFilePath -Raw)).ArrayOfCMPackage).CMPackage) | Where-Object { $_.Name -match $Filter }
				}
				"AdminService" {
					Write-CMLogEntry -Value " - Querying AdminService for driver package instances"
					$Packages = @(Get-AdminServiceItem -Resource $UrlResource -AdminServiceEndpoint $AdminService )
				}
			}#switch
			switch ($OperationalMode) {
				"Production" { $Packages = $Packages | Where-Object { $_.Name -notmatch "Pilot|Legacy|Retired" } }
				"Pilot" { $Packages = $Packages | Where-Object { $_.Name -match "Pilot" } }
			}#switch
		}
		catch [System.Exception] {
			New-ErrorRecord -Message " - An error occurred while calling $($DriverSelection) for a list of available driver packages. Error message: $($_.Exception.Message)" -ThrowError
		}
		# Match detected driver packages from web service call with computer details and OS image details gathered previously
		$Packages = Confirm-DriverPackage -ComputerData $ComputerData -DriverPackage $Packages -OSVersionFallback:$FallBack
		switch ($Packages.Count) {
			0 {
				if ($FallBack.IsPresent) { $Packages = Get-DriverPackages -ComputerData $ComputerData -AdminService $AdminService -UrlResource "/SMS_Package?`$filter=contains(Name,'Driver Fallback Package')" }
				else { New-ErrorRecord -Message " - No driver packages retrieved from $($DriverSelection) matching operational mode: $($OperationalMode)" -ThrowError }
			}
			1 { Write-CMLogEntry -Value " - Successfully completed validation with a single driver package, script execution is allowed to continue" }
			default { Write-CMLogEntry -Value " - Retrieved a total of $($Packages.Count) <$($OperationalMode)> driver packages from $($DriverSelection)" }
		}
		return $Packages
	}
	function Confirm-DriverPackage {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the computer details object from Get-ComputerDetails function.")]
			[PSCustomObject]$ComputerData,
			[parameter(Mandatory, HelpMessage = "Specify the driver package object to be validated.")]
			[System.Object[]]$DriverPackages,
			[parameter(HelpMessage = "Check for drivers packages that match previous versions of Windows.")]
			[switch]$OSVersionFallback
		)
		Write-CMLogEntry -Value "[DriverPackage]: Starting driver package matching phase"
		[System.Collections.ArrayList]$DriverPackagesList = @()
		foreach ($DriverPackage in $DriverPackages) {
			# Add driver package model details depending on manufacturer to custom driver package details object
			$Model = $Architecture = $OSName = $OSVersion = $SystemSKU = ""
			# - HP computer models require the manufacturer name to be a part of the model name, other manufacturers do not
			try {
				switch ($DriverPackage.Manufacturer) {
					{ @("Hewlett-Packard", "HP") -contains $_ } { $Model = $DriverPackage.Name.Replace("Hewlett-Packard", "HP") }
					default { $Model = $DriverPackage.Name.Replace($DriverPackage.Manufacturer, "") }
				}
				$Model = $Model.Replace(" - ", ":").Split(":").Trim()[1]
			}
			catch [System.Exception] { Write-CMLogEntry -Value "Failed. Error: $($_.Exception.Message)" -Severity 3 }
			switch -Regex ($DriverPackage.Name) {
				"^.*(?<Architecture>(x86|x64)).*" { $Architecture = $Matches.Architecture }
				"^.*Windows.*(?<OSName>(10)).*" { $OSName = -join @("Windows ", $Matches.OSName) }
				"^.*Windows.*(?<OSVersion>(\d){4}).*" { $OSVersion = $Matches.OSVersion }
			}
			#retrieve SystemSKU from non-empty description field of driver package
			try { [string]$DriverPackage.Description.Split(":").Replace("(", "").Replace(")", "")[1] }
			catch { $SystemSKU = "" }
			#using logical operators for validation of driver package compliancy with computer data fields
			$OSNameMatch = ($OSName -eq $ComputerData.OSName)
			$OSVersionMatch = ($OSVersion -eq $ComputerData.OSVersion)
			if (-not $OSVersionMatch -and $OSVersionFallback.IsPresent) { $OSVersionMatch = ($OSVersion -eq $ComputerData.FallBackOSVersion) }
			$OSArchitectureMatch = ($Architecture -eq $ComputerData.Architecture)
			$ManufacturerMatch = ($DriverPackage.Manufacturer -like $ComputerData.Manufacturer)
			$ComputerModelMatch = ($Model -like $ComputerData.Model)
			$SystemSKUMatch = ($SystemSKU -like $ComputerData.SystemSKU)
			if (-not $SystemSKUMatch) { $SystemSKUMatch = ($SystemSKU -like $ComputerData.FallbackSKU) }
			# Construct custom object to hold values for current driver package properties used for matching with current computer details
			$DriverPackageDetails = [PSCustomObject]@{
				PackageName    = $DriverPackage.Name
				PackageID      = $DriverPackage.PackageID
				PackageVersion = $DriverPackage.Version
				DateCreated    = $DriverPackage.SourceDate
				Manufacturer   = $DriverPackage.Manufacturer
				Model          = $Model
				SystemSKU      = $SystemSKU
				OSName         = $OSName
				OSVersion      = $OSVersion
				Architecture   = $Architecture
			}
			#all matches must be true to confirm this driver package, grouping boolean operators allows pretty awesome validation rules :-)
			[bool]$DetectionMethodResult = ($OSNameMatch -band $OSVersionMatch -band $OSArchitectureMatch -band $ManufacturerMatch -band $ComputerModelMatch -band $SystemSKUMatch)
			if ($DetectionMethodResult) { $DriverPackagesList.Add($DriverPackageDetails) | Out-Null }
		}#foreach DriverPackage
		$DriverPackagesList.Sort()
		Write-CMLogEntry -Value " - Found $($DriverPackagesList.Count) driver package(s) matching required computer details"
		Write-CMLogEntry -Value "[DriverPackage]: Completed driver package matching phase"
		return $DriverPackagesList
	}
	function Invoke-DownloadDriverPackageContent {
		param(
			[parameter(Mandatory)][string]$Package
		)
		Write-CMLogEntry -Value "[DriverPackageDownload]: Starting driver package download phase"
		Write-CMLogEntry -Value " - Attempting to download content files for matched driver package: $($Package.PackageName)"
		# Depending on current deployment type, attempt to download driver package content
		#set default cmdlet params and reset value(s) if needed
		DestinationLocationType = "Custom"
		DestinationVariableName = "OSDDriverPackage"
		CustomLocationPath      = ""
		switch ($DeploymentType) {
			"PreCache" {
				if ($PSBoundParameters.ContainsKey('PreCachePath')) {
					while (-not (Test-Path -Path $PreCachePath)) {
						Write-CMLogEntry -Value " - Attempting to create PreCachePath directory, as it doesn't exist: $($PreCachePath)"
						try { New-Item -Path $PreCachePath -ItemType Directory -Force -ErrorAction Stop | Out-Null }
						catch [System.Exception] {
							New-ErrorRecord -Message " - Failed to create PreCachePath directory '$($PreCachePath)'. Error message: $($_.Exception.Message)" -ThrowError
							$PreCachePath = $env:TEMP
						}
					}
					$CustomLocationPath = $PreCachePath
				}
				else { $DestinationLocationType = "CCMCache" }
			}
			default { $CustomLocationPath = "%_SMSTSMDataPath%\DriverPackage" }
		}#switch
		#setting various TS variables
		Set-MDMTaskSequenceVariable -TSVariable "OSDDownloadDownloadPackages" -TsValue $Package.ID
		Set-MDMTaskSequenceVariable -TSVariable "OSDDownloadDestinationLocationType" -TsValue $DestinationLocationType
		Set-MDMTaskSequenceVariable -TSVariable "OSDDownloadDestinationVariable" -TsValue $DestinationVariableName
		switch ($DestinationLocationType) {
			"Custom" { Set-MDMTaskSequenceVariable -TSVariable "OSDDownloadDestinationPath" -TsValue $CustomLocationPath }
			"TSCache" {}
			"CCMCache" {}
			default {}
		}
		# Set SMSTSDownloadRetryCount to 1000 to overcome potential BranchCache issue that will cause 'SendWinHttpRequest failed. 80072efe'
		Set-MDMTaskSequenceVariable -TSVariable "SMSTSDownloadRetryCount" -TsValue 1000
		try {
			$InstallMode = "WinPE"
			$FilePath = "OSDDownloadContent.exe"
			if ($Script:TSEnvironment.Value("_SMSTSInWinPE") -eq $false) {
				$InstallMode = "FullOS"
				$FilePath = Join-Path -Path $env:windir -ChildPath "CCM\OSDDownloadContent.exe"
			}
			Write-CMLogEntry -Value " - Starting package content download process ($($InstallMode)), this might take some time"
			$ReturnCode = Invoke-Executable -FilePath $FilePath
			# Reset SMSTSDownloadRetryCount to 5 after attempted download
			Set-MDMTaskSequenceVariable -TSVariable "SMSTSDownloadRetryCount" -TsValue 5
			# Match on return code
			if ($ReturnCode -ne 0) { New-ErrorRecord -Message " - Failed to download package content with PackageID '$($PackageID)'. Return code was: $($ReturnCode)" -ThrowError }
		}
		catch [System.Exception] { New-ErrorRecord -Message " - An error occurred while attempting to download package content. Error message: $($_.Exception.Message)" -ThrowError }
		if ($ReturnCode -eq 0) {
			$DriverPackageContentLocation = $Script:TSEnvironment.Value("OSDDriverPackage01")
			Write-CMLogEntry -Value " - Driver package content files was successfully downloaded to: $($DriverPackageContentLocation)"
			# Handle return value for successful download of driver package content files
			return $DriverPackageContentLocation
		}
		else {
			New-ErrorRecord -Message " - Driver package content download process returned an unhandled exit code: $($ReturnCode)" -ThrowError
		}
		Write-CMLogEntry -Value "[DriverPackageDownload]: Completed driver package download phase"
	}
	function Install-DriverPackageContent {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the full local path to the downloaded driver package content.")]
			[ValidateNotNullOrEmpty()]
			[string]$ContentLocation
		)
		Write-CMLogEntry -Value "[DriverPackageInstall]: Starting driver package install phase"
		# Detect if downloaded driver package content is a compressed archive that needs to be extracted before drivers are installed
		$DriverPackageCompressedFile = Get-ChildItem -Path $ContentLocation -Filter "DriverPackage.*"
		if ($null -ne $DriverPackageCompressedFile) {
			Write-CMLogEntry -Value " - Downloaded driver package content contains a compressed archive with driver content"
			# Detect if compressed format is Windows native zip or 7-Zip exe
			switch -wildcard ($DriverPackageCompressedFile.Name) {
				"*.zip" {
					try {
						# Expand compressed driver package archive file
						Write-CMLogEntry -Value " - Attempting to decompress driver package content file: $($DriverPackageCompressedFile.Name) to: $($ContentLocation)"
						Expand-Archive -Path $DriverPackageCompressedFile.FullName -DestinationPath $ContentLocation -Force -ErrorAction Stop
						Write-CMLogEntry -Value " - Successfully decompressed driver package content file"
					}
					catch [System.Exception] {
						New-ErrorRecord -Message " - Failed to decompress driver package content file. Error message: $($_.Exception.Message)" -ThrowError
					}
					try {
						# Remove compressed driver package archive file
						if (Test-Path -Path $DriverPackageCompressedFile.FullName) { Remove-Item -Path $DriverPackageCompressedFile.FullName -Force -ErrorAction Stop }
					}
					catch [System.Exception] {
						New-ErrorRecord -Message " - Failed to remove compressed driver package content file after decompression. Error message: $($_.Exception.Message)" -ThrowError
					}
				}
				"*.exe" {
					Write-CMLogEntry -Value " - Attempting to decompress self extracting driver package: $($DriverPackageCompressedFile.Name) to destinationfolder: $($ContentLocation)"
					$ReturnCode = Invoke-Executable -FilePath $DriverPackageCompressedFile.FullName -Arguments "-o`"$($ContentLocation)`" -y"
					if ($ReturnCode -eq 0) {
						Write-CMLogEntry -Value " - Successfully decompressed driver package"
						Remove-Item -Path $DriverPackageCompressedFile.FullName -Force -ErrorAction SilentlyContinue
					}
					else { New-ErrorRecord -Message " - The self-extracting driver package returned an error: $($ReturnCode)" -ThrowError }
				}
				"*.wim" {
					try {
						# Create mount location for driver package WIM file
						$DriverPackageMountLocation = Join-Path -Path $ContentLocation -ChildPath "Mount"
						if (-not(Test-Path -Path $DriverPackageMountLocation)) {
							Write-CMLogEntry -Value " - Creating mount location directory: $($DriverPackageMountLocation)"
							New-Item -Path $DriverPackageMountLocation -ItemType "Directory" -Force | Out-Null
						}
					}
					catch [System.Exception] {
						New-ErrorRecord -Message " - Failed to create mount location for WIM file. Error message: $($_.Exception.Message)" -ThrowError
					}
					try {
						# Expand compressed driver package WIM file
						Write-CMLogEntry -Value " - Attempting to mount driver package content WIM file: $($DriverPackageCompressedFile.Name) at: $($DriverPackageMountLocation)"
						Mount-WindowsImage -ImagePath $DriverPackageCompressedFile.FullName -Path $DriverPackageMountLocation -Index 1 -ErrorAction Stop
						Write-CMLogEntry -Value " - Successfully mounted driver package content WIM file"
						Write-CMLogEntry -Value " - Copying items from mount directory"
						Get-ChildItem -Path	$DriverPackageMountLocation | Copy-Item -Destination $ContentLocation -Recurse -Container
					}
					catch [System.Exception] {
						New-ErrorRecord -Message " - Failed to mount driver package content WIM file. Error message: $($_.Exception.Message)" -ThrowError
					}
				}
			}
		}
		switch ($DeploymentType) {
			"BareMetal" {
				# Apply drivers recursively from downloaded driver package location
				Write-CMLogEntry -Value " - Attempting to apply drivers using dism.exe located in: $($ContentLocation)"
				# Determine driver injection method from parameter input
				Write-CMLogEntry -Value " - DriverInstallMode is currently set to: $($DriverInstallMode)"
				switch ($DriverInstallMode) {
					"Single" {
						try {
							# Get driver full path and install each driver seperately
							$DriverINFs = Get-ChildItem -Path $ContentLocation -Recurse -Filter "*.inf" -ErrorAction Stop | Select-Object -Property FullName, Name
							if ($null -ne $DriverINFs) {
								foreach ($DriverINF in $DriverINFs) {
									# Install specific driver
									Write-CMLogEntry -Value " - Attempting to install driver: $($DriverINF.FullName)"
									$ApplyDriverInvocation = Invoke-Executable -FilePath "dism.exe" -Arguments "/Image:$($Script:TSEnvironment.Value('OSDTargetSystemDrive'))\ /Add-Driver /Driver:`"$($DriverINF.FullName)`""
									# Validate driver injection
									if ($ApplyDriverInvocation -eq 0) { Write-CMLogEntry -Value " - Successfully installed driver using dism.exe" }
									else { Write-CMLogEntry -Value " - An error occurred while installing driver. Continuing with warning code: $($ApplyDriverInvocation). See DISM.log for more details" -Severity 2 }
								}
							}
							else { New-ErrorRecord -Message " - An error occurred while enumerating driver paths, downloaded driver package does not contain any INF files" -ThrowError }
						}
						catch [System.Exception] { New-ErrorRecord -Message " - An error occurred while installing drivers. See DISM.log for more details" -ThrowError }
					}
					"Recurse" {
						# Apply drivers recursively
						$ApplyDriverInvocation = Invoke-Executable -FilePath "dism.exe" -Arguments "/Image:$($Script:TSEnvironment.Value('OSDTargetSystemDrive'))\ /Add-Driver /Driver:$($ContentLocation) /Recurse"
						# Validate driver injection
						if ($ApplyDriverInvocation -eq 0) { Write-CMLogEntry -Value " - Successfully installed drivers recursively in driver package content location using dism.exe" }
						else { Write-CMLogEntry -Value " - An error occurred while installing drivers. Continuing with warning code: $($ApplyDriverInvocation). See DISM.log for more details" -Severity 2 }
					}
				}
			}
			"OSUpgrade" {
				# For OSUpgrade, don't attempt to install drivers as this is handled by setup.exe when used together with OSDUpgradeStagedContent
				Write-CMLogEntry -Value " - Driver package content downloaded successfully and located in: $($ContentLocation)"
				Set-MDMTaskSequenceVariable -TSVariable "OSDUpgradeStagedContent" -TsValue $ContentLocation
				Write-CMLogEntry -Value " - Successfully completed driver package staging process"
			}
			"DriverUpdate" {
				# Apply drivers recursively from downloaded driver package location
				Write-CMLogEntry -Value " - Driver package content downloaded successfully, attempting to apply drivers using pnputil.exe located in: $($ContentLocation)"
				$ApplyDriverInvocation = Invoke-Executable -FilePath "powershell.exe" -Arguments "pnputil /add-driver $(Join-Path -Path $ContentLocation -ChildPath '*.inf') /subdirs /install | Out-File -FilePath (Join-Path -Path $($LogsDirectory) -ChildPath 'Install-Drivers.txt') -Force"
				Write-CMLogEntry -Value " - Successfully installed drivers"
			}
			"PreCache" {
				# Driver package content downloaded successfully, log output and exit script
				Write-CMLogEntry -Value " - Driver package content successfully downloaded and pre-cached to: $($ContentLocation)"
			}
		}
		# Cleanup potential compressed driver package content
		if ($null -ne $DriverPackageCompressedFile) {
			switch -wildcard ($DriverPackageCompressedFile.Name) {
				"*.wim" {
					try {
						# Attempt to dismount compressed driver package content WIM file
						Write-CMLogEntry -Value " - Attempting to dismount driver package content WIM file: $($DriverPackageCompressedFile.Name) at $($DriverPackageMountLocation)"
						Dismount-WindowsImage -Path $DriverPackageMountLocation -Discard -ErrorAction Stop
						Write-CMLogEntry -Value " - Successfully dismounted driver package content WIM file"
					}
					catch [System.Exception] {
						New-ErrorRecord -Message " - Failed to dismount driver package content WIM file. Error message: $($_.Exception.Message)" -ThrowError
					}
				}
			}
		}
	}
}#begin

End {
	if ($DebugMode.IsPresent) { Write-CMLogEntry -Value " - Apply Driver Package script has successfully completed in <debug mode>" }
	# Reset OSDDownloadContent.exe dependant variables before next task sequence step
	else { @("OSDDownloadDownloadPackages", "OSDDownloadDestinationLocationType", "OSDDownloadDestinationVariable", "OSDDownloadDestinationPath") | % { Set-MDMTaskSequenceVariable -TSVariable $_ } }
	Write-CMLogEntry -Value "[ApplyDriverPackage]: Completed Apply Driver Package process"
	# Write final output to log file
	Out-File -FilePath $LogFilePath -InputObject $script:LogEntries -Encoding default -NoClobber -Force
}