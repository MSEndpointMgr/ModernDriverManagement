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
.PARAMETER OSVersion
Define the value that will be used as the target operating system version e.g. '2004'.
.PARAMETER OSVersionFallback
Use this switch to check for drivers packages that matches earlier versions of Windows than what's specified as input for OSVersion.
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
.PARAMETER QuerySource
Specify to download drivers using an XML file or the Admin service (default) as query source.
.PARAMETER UseDriverFallback
Activate search for a driver fallback package if SystemSKU or computer model does not return exact results.
.PARAMETER PreCachePath
Specify a custom path for the PreCache directory, overriding the default CCMCache directory, fallback is temp folder.
.PARAMETER DebugMode
Set the script to operate in 'DebugMode', hence no actual installation of drivers.
.PARAMETER XMLFileName
Option to override (default) name of the XML selection file: MDMPackages.xml
.PARAMETER LogFileName
Option to override (default) name of the script output logfile: InvokeMDMPackage.log
.EXAMPLE
# Detect, download and apply drivers during OS deployment with ConfigMgr:
.\Invoke-MDMPackage.ps1 -Endpoint "CM01.domain.com" -OSVersion 1909
# Detect, download and apply drivers during OS deployment with ConfigMgr and use a driver fallback package if no matching driver package can be found:
.\Invoke-MDMPackage.ps1 -Endpoint "CM01.domain.com" -OSVersion 1909 -UseDriverFallback
# Detect, download and apply drivers during OS deployment with ConfigMgr and check for driver packages that matches an earlier version than what's specified for OSVersion:
.\Invoke-MDMPackage.ps1 -DeploymentType BareMetal -Endpoint "CM01.domain.com" -OSVersion 1909 -OSVersionFallback
# Detect and download drivers during OS upgrade with ConfigMgr:
.\Invoke-MDMPackage.ps1 -DeploymentType OSUpgrade -Endpoint "CM01.domain.com" -OSVersion 1909
# Detect, download and update a device with latest drivers for an running operating system using ConfigMgr:
.\Invoke-MDMPackage.ps1 -DeploymentType DriverUpdate -Endpoint "CM01.domain.com"
# Detect and download (pre-caching content) during OS upgrade with ConfigMgr:
.\Invoke-MDMPackage.ps1 -DeploymentType PreCache -Endpoint "CM01.domain.com" -OSVersion 1909
# Detect and download (pre-caching content) to a custom path during OS upgrade with ConfigMgr:
.\Invoke-MDMPackage.ps1 -DeploymentType PreCache -Endpoint "CM01.domain.com" -OSVersion 1909 -PreCachePath "$($env:SystemDrive)\MDMDrivers"
# Run in a debug mode for testing purposes on the targeted computer model:
.\Invoke-MDMPackage.ps1 -DebugMode -Endpoint "CM01.domain.com" -UserName "svc@domain.com" -Password "svc-password" -OSVersion 2004
# Run in a debug mode for testing purposes and overriding the (automatically detected) computer specifications:
.\Invoke-MDMPackage.ps1 -DebugMode -Endpoint "CM01.domain.com" -UserName "svc@domain.com" -Password "svc-password" -OSVersion 1909 -Manufacturer "Lenovo" -ComputerModel "Thinkpad X1 Tablet" -SystemSKU "20KKS7"
# Detect, download and apply drivers during OS deployment with ConfigMgr and use an XML table as the source of driver package details instead of the AdminService:
.\Invoke-MDMPackage.ps1 -OSVersion "1909" -OSVersionFallback "1903" -QuerySource XML -XMLFileName "Install32bitDrivers.xml"
.NOTES
FileName:	Invoke-MDMPackage.ps1
CoAuthor:	Chris Kenis
Contact: 	@KICTS
Created: 	2020-12-01
Contributors:
Version history:
4.0.8.1 - (2020-12-08) - Alternative version with some code shuffling and rewrite of functions retaining expected output
4.0.8.2 - (2020-12-15) - Forked version of Invoke-CMApplyDriverPackage with major rewrite of code maintaining expected functionality
4.0.9.1 - (2021-01-05) - Use of Dynamic Param for validating and providing default values for OSVersion + minor code update and replace of Get-WMIObject with Get-CIMInstance in Get-ComputerData function
4.0.9.2 - (2021-01-13) - Merged Admin endpoint code into 1 function, minor corrections in Get-ComputerData
4.0.9.3 - (2021-01-14) - overlooked typo in notes: TargetOSVersion --> OSVersion, changed ApplyDriverPackage moniker to InvokeMDMPackage as a more generic description
4.0.9.7 - (2021-01-21) - Replaced the word "Driver" with "MDM" where appropriate + first attempt to incorporate BIOS packages in the same script, ToDo: review Install-MDMPackageContent

#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
	[parameter(HelpMessage = "Specify the deployment type mode for MDM package deployments: 'BareMetal' (= default), 'OSUpdate', 'SystemUpdate' or 'PreCache'.")]
	[ValidateSet("BareMetal", "OSUpdate", "SystemUpdate", "PreCache")]
	[string]$DeploymentType = "BareMetal",
	[parameter(HelpMessage = "Specify the fully qualified domain name of the server hosting a valid webservice, e.g. CM01.domain.local.")]
	[string]$Endpoint,
	[parameter(ParameterSetName = "Debug", HelpMessage = "Specify the service account user name used for authenticating against the endpoint.")]
	[string]$UserName,
	[parameter(ParameterSetName = "Debug", HelpMessage = "Specify the service account password used for authenticating against the endpoint.")]
	[string]$Password,
	[parameter(HelpMessage = "Use this switch to check for MDM packages that match a previous version of Windows.")]
	[switch]$OSVersionFallback,
	[parameter(HelpMessage = "Define the value that will be used as the target operating system architecture e.g. 'x64'.")]
	[ValidateSet("x64", "x86")]
	[string]$OSArchitecture,
	[parameter(HelpMessage = "Override the automatically detected computer manufacturer.")]
	[string]$Manufacturer,
	[parameter(HelpMessage = "Override the automatically detected computer model.")]
	[string]$ComputerModel,
	[parameter(HelpMessage = "Override the automatically detected SystemSKU (manufacturer's model/type code).")]
	[string]$SystemSKU,
	[parameter(HelpMessage = "Define a filter to only return matched BIOS or Driver (= default) packages when querying via a webservice.")]
	[ValidateSet("BIOS", "Driver")]
	[string]$Filter = "Driver",
	[parameter(HelpMessage = "Set operational mode to Production (= default) or Pilot when querying MDM packages via a webservice.")]
	[ValidateSet("Production", "Pilot")]
	[string]$OperationalMode = "Production",
	[parameter(HelpMessage = "Specify whether to invoke DISM.exe with Recurse (= default) option or spawn a Single new process for each driver.")]
	[ValidateSet("Single", "Recurse")]
	[string]$InstallMode = "Recurse",
	[parameter(HelpMessage = "Specify the source to query for selection of packages to apply: XML or WebService (= default)")]
	[ValidateSet("XML", "WebService")]
	[string]$QuerySource = "WebService",
	[parameter(HelpMessage = "Enable search for MDM fallback package(s) if none are returned based on computer details.")]
	[switch]$UseFallbackPackage,
	[parameter(HelpMessage = "Specify a custom path for the PreCache directory, overriding the default CCMCache directory.")]
	[string]$PreCachePath,
	[parameter(HelpMessage = "Set the script to operate in 'DebugMode' deployment type mode so nothing will be downloaded or installed.")]
	[switch]$DebugMode,
	[parameter(HelpMessage = "Name of the XML file specifying the MDM package(s) to apply: MDMPackages.xml (= default) ")]
	[string]$XMLFileName = "MDMPackages.xml",
	[parameter(HelpMessage = "Name of the log file for script output: InvokeMDMPackage.log (= default)")]
	[string]$LogFileName = "InvokeMDMPackage.log"
)

DynamicParam {
	# using a dynamic param for validation of script parameter(s) and script variable(s) with just one hashtable to define
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
	$parameterName = 'OSVersion'
	$parameterAttribute = New-Object System.Management.Automation.ParameterAttribute
	$ParameterAttribute.HelpMessage = "Override the automatically detected (shorthand) OS version, e.g. 2004"
	$attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
	$attributeCollection.Add($parameterAttribute)
	$arrSet = $script:OsBuildVersions.Values
	$ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
	$attributeCollection.Add($ValidateSetAttribute)
	$RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($parameterName, [string], $AttributeCollection)
	$runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
	$runtimeParameterDictionary.Add($parameterName, $RuntimeParameter)
	return $runtimeParameterDictionary
}

Process {
	Write-CMLogEntry -Value "[InvokeMDMPackage]: Apply $($OperationalMode) MDM Package(s) initiated in $($DeploymentType) deployment mode using script version $($ScriptVersion)."
	try {
		# Determine computer OS version, Architecture, Manufacturer, Model, SystemSKU and FallbackSKU
		$ComputerData = Get-ComputerData
		#Resolve, validate, test and authenticate the MDM webservice
		$WebService = Get-MDMWebService
		# Construct array list for matched MDM packages
		$MDMPackageList = New-Object -TypeName "System.Collections.ArrayList"
		switch ($QuerySource) {
			"XML" {
				# Define the path for the pre-downloaded XML Package Logic file
				$XMLPackageLogicFile = Join-Path -Path $Script:TSEnvironment.Value("MDMXMLPackage01") -ChildPath $XMLFileName
				if (Test-Path -Path $XMLPackageLogicFile) { $MDMPackageList = Get-MDMPackages -ComputerData $ComputerData -XMLFilePath $XMLPackageLogicFile }
				else { New-ErrorRecord -Message " - Failed to locate required $($XMLFileName) logic file, ensure it has been pre-downloaded in a Download Package Content step before running this script" -ThrowError }
			}
			"WebService" {
				# Retrieve available MDM packages from a web service
				$MDMPackageList = Get-MDMPackages -ComputerData $ComputerData -FallBack:$UseFallbackPackage -WebService $WebService -UrlResource "/SMS_Package?`$filter=contains(Name,'$($Filter)')"
			}
		}#switch
		# At this point, the code below here is not allowed to be executed in debug mode, as it requires access to the Microsoft.SMS.TSEnvironment COM object
		if (-not $DebugMode.IsPresent) {
			# Attempt to download the matched package content files from distribution point
			$MDMPackageContentLocation = Invoke-MDMPackageContent -Package $MDMPackageList[0]
			# Depending on deployment type, take action accordingly when applying the MDM package files
			Install-MDMPackageContent -ContentLocation $MDMPackageContentLocation
			Write-CMLogEntry -Value "[MDMPackageInstall]: Completed MDM package install phase"
		}
	}
	catch [System.Exception] {
		New-ErrorRecord -Message "[InvokeMDMPackage]: Apply MDM Package process failed, please refer to previous error or warning messages"
		# Main try-catch block was triggered, this should cause the script to fail with exit code 1
		exit 1
	}
}#process

Begin {
	[version]$ScriptVersion = "4.0.9.7"
	# Set script error preference variable
	$ErrorActionPreference = "Stop"
	$LogsDirectory = Join-Path -Path $env:SystemRoot -ChildPath "Temp"
	try {
		$Script:TSEnvironment = New-Object -ComObject "Microsoft.SMS.TSEnvironment" -ErrorAction Stop
		$LogsDirectory = $Script:TSEnvironment.Value("_SMSTSLogPath")
	}
	catch [System.Exception] { Write-Warning -Message "Script is not running in a Task Sequence" }
	$LogFilePath = Join-Path -Path $LogsDirectory -ChildPath $LogFileName
	[System.Collections.ArrayList]$script:LogEntries = @()

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
		$script:LogEntries.Add("<![LOG[{0}]LOG]!><time=""{1}"" date=""{2}"" component=""InvokeMDMPackage"" context=""{3}"" type=""{4}"" thread=""{5}"" file=""{6}"">") -f $Value, $Time, $Date, $Context, $Severity, $PID, $File | Out-Null
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
	function Get-MDMWebService {
		Write-CMLogEntry -Value "[WebService]: Starting endpoint validation phase"
		# Validation of service account credentials set via TS environment variables or script parameter input, empty string will throw error in ConvertTo-ObfuscatedString function
		if (-not ($PSBoundParameters.ContainsKey('UserName'))) {
			try {
				$UserName = $Script:TSEnvironment.Value("MDMUserName")
				$ObfuscatedUserName = ConvertTo-ObfuscatedString -InputObject $UserName
				Write-CMLogEntry -Value " - Successfully read service account username: $($ObfuscatedUserName)"
			}
			catch {
				if ($DebugMode.IsPresent) { New-ErrorRecord -Message " - Service account username could not be determined from parameter input" -ThrowError }
				New-ErrorRecord -Message " - Required service account username could not be determined from TS environment variable [MDMUserName]" -ThrowError
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
				New-ErrorRecord -Message " - Required service account password could not be determined from TS environment variable [MDMPassword]" -ThrowError
			}
		}
		$WebServiceEndpointType = "Internal"
		switch ($DeploymentType) {
			"BareMetal" {
				$SMSInWinPE = $Script:TSEnvironment.Value("_SMSTSInWinPE")
				if ($SMSInWinPE -eq $true) { Write-CMLogEntry -Value " - Script is running within a task sequence in WinPE phase, using EndPoint script parameter for configuring WebService" }
				else { New-ErrorRecord -Message " - Script is not running in WinPE during $($DeploymentType) deployment type, this is not a supported scenario" -ThrowError }
			}
			"OSUpdate" {}
			"SystemUpdate" {}
			"PreCache" {}
			default {
				Write-CMLogEntry -Value " - Attempting to determine WebService endpoint type based on current active Management Point candidates and from ClientInfo class"
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
								Write-CMLogEntry -Value " - Successfully read external endpoint address for WebService through CMG from TS environment variable 'MDMExternalEndpoint': $($ExternalEndpoint)"
							}
							else { New-ErrorRecord -Message " - Required external endpoint address for WebService through CMG could not be determined from TS environment variable [MDMExternalEndpoint]" -ThrowError }
							# Attempt to read TSEnvironment variable MDMClientID
							$ClientID = $Script:TSEnvironment.Value("MDMClientID")
							if (-not([string]::IsNullOrEmpty($ClientID))) {
								Write-CMLogEntry -Value " - Successfully read client identification for WebService through CMG from TS environment variable 'MDMClientID': $($ClientID)"
							}
							else { New-ErrorRecord -Message " - Required client identification for WebService through CMG could not be determined from TS environment variable [MDMClientID]" -ThrowError }
							# Attempt to read TSEnvironment variable MDMTenantName
							$TenantName = $Script:TSEnvironment.Value("MDMTenantName")
							if (-not([string]::IsNullOrEmpty($TenantName))) {
								Write-CMLogEntry -Value " - Successfully read client identification for WebService through CMG from TS environment variable 'MDMTenantName': $($TenantName)"
							}
							else { New-ErrorRecord -Message " - Required client identification for WebService through CMG could not be determined from TS environment variable [MDMTenantName]" -ThrowError }
							$WebServiceEndpointType = "External"
						}
						else { New-ErrorRecord -Message " - Detected as an Internet client but unable to acquire External WebService endpoint, bailing out..." -ThrowError }
					}
					$false {
						if ($ActiveMPInternalCandidatesCount -lt 1) { New-ErrorRecord -Message " - Detected as an Intranet client but unable to acquire Internal WebService endpoint, bailing out..." -ThrowError }
					}
				}#switch
			}#default
		}#switch
		# Construct PSCredential object for WebService authentication, this is required for both endpoint types
		$Credential = Get-AuthCredential -UserName $UserName -Password $Password
		switch ($WebServiceEndpointType) {
			"Internal" {
				if (-not $PSBoundParameters.Contains("Endpoint")) {
					$Endpoint = $ActiveMPCandidates | Where-Object Locality -gt 0 | Select-Object -First 1 -ExpandProperty MP
				}
				$WebServiceURL = "https://{0}/AdminService/wmi" -f $Endpoint
			}
			"External" { 
				$WebServiceURL = "{0}/wmi" -f $ExternalEndpoint
				# Get authentication token needed against the Cloud Management Gateway
				$AuthToken = Get-AuthToken -TenantName $TenantName -ClientID $ClientID -Credential $Credential
			}
		}
		Write-CMLogEntry -Value " - WebService endpoint type is: $($WebServiceEndpointType) and can be reached via URL: $($WebServiceURL)"
		$WebServiceEndpoint = [PSCustomObject]@{
			URL        = $WebServiceURL
			Type       = $WebServiceEndpointType
			ClientID   = $ClientID
			TenantName = $TenantName
			AuthToken  = $AuthToken
			Credential = $Credential
		}
		Write-CMLogEntry -Value "[WebService]: Completed WebService endpoint phase"
		return $WebServiceEndpoint
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
	function Get-MDMWebServiceItem {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the resource for the WebService API call, e.g. '/SMS_Package'.")]
			[ValidateNotNullOrEmpty()]
			[string]$Resource,
			[PSCustomObject]$WebServiceEndpoint
		)
		$WebServiceUri = $WebServiceEndpoint.URL + $Resource
		Write-CMLogEntry -Value " - Calling WebService endpoint with URI: $($WebServiceUri)"
		switch ($WebServiceEndpoint.Type) {
			"External" {
				try { $WebServiceResponse = Invoke-RestMethod -Method Get -Uri $WebServiceUri -Headers $WebServiceEndpoint.AuthToken -ErrorAction Stop }
				catch [System.Exception] { New-ErrorRecord -Message " - Failed to retrieve available package items from WebService endpoint. Error message: $($PSItem.Exception.Message)" -ThrowError }
			}
			"Internal" {
				try { $WebServiceResponse = Invoke-RestMethod -Method Get -Uri $WebServiceUri -Credential $WebServiceEndpoint.Credential -ErrorAction Stop	}
				catch [System.Security.Authentication.AuthenticationException] {
					Write-CMLogEntry -Value " - The remote WebService endpoint certificate is invalid according to the validation procedure. Error message: $($PSItem.Exception.Message)" -Severity 2
					Write-CMLogEntry -Value " - Will attempt to set the current session to ignore self-signed certificates and retry WebService endpoint connection" -Severity 2
					# Convert encoded base64 string for ignore self-signed certificate validation functionality
					$CertificationValidationCallbackEncoded = "DQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAdQBzAGkAbgBnACAAUwB5AHMAdABlAG0AOwANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAB1AHMAaQBuAGcAIABTAHkAcwB0AGUAbQAuAE4AZQB0ADsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAdQBzAGkAbgBnACAAUwB5AHMAdABlAG0ALgBOAGUAdAAuAFMAZQBjAHUAcgBpAHQAeQA7AA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHUAcwBpAG4AZwAgAFMAeQBzAHQAZQBtAC4AUwBlAGMAdQByAGkAdAB5AC4AQwByAHkAcAB0AG8AZwByAGEAcABoAHkALgBYADUAMAA5AEMAZQByAHQAaQBmAGkAYwBhAHQAZQBzADsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAcAB1AGIAbABpAGMAIABjAGwAYQBzAHMAIABTAGUAcgB2AGUAcgBDAGUAcgB0AGkAZgBpAGMAYQB0AGUAVgBhAGwAaQBkAGEAdABpAG8AbgBDAGEAbABsAGIAYQBjAGsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAewANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHAAdQBiAGwAaQBjACAAcwB0AGEAdABpAGMAIAB2AG8AaQBkACAASQBnAG4AbwByAGUAKAApAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAewANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAaQBmACgAUwBlAHIAdgBpAGMAZQBQAG8AaQBuAHQATQBhAG4AYQBnAGUAcgAuAFMAZQByAHYAZQByAEMAZQByAHQAaQBmAGkAYwBhAHQAZQBWAGEAbABpAGQAYQB0AGkAbwBuAEMAYQBsAGwAYgBhAGMAawAgAD0APQBuAHUAbABsACkADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAUwBlAHIAdgBpAGMAZQBQAG8AaQBuAHQATQBhAG4AYQBnAGUAcgAuAFMAZQByAHYAZQByAEMAZQByAHQAaQBmAGkAYwBhAHQAZQBWAGEAbABpAGQAYQB0AGkAbwBuAEMAYQBsAGwAYgBhAGMAawAgACsAPQAgAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAZABlAGwAZQBnAGEAdABlAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAKAANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAATwBiAGoAZQBjAHQAIABvAGIAagAsACAADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAFgANQAwADkAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBlAHIAdABpAGYAaQBjAGEAdABlACwAIAANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAWAA1ADAAOQBDAGgAYQBpAG4AIABjAGgAYQBpAG4ALAAgAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABTAHMAbABQAG8AbABpAGMAeQBFAHIAcgBvAHIAcwAgAGUAcgByAG8AcgBzAA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAKQANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHsADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHIAZQB0AHUAcgBuACAAdAByAHUAZQA7AA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAfQA7AA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAB9AA0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAfQANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAB9AA0ACgAgACAAIAAgACAAIAAgACAA"
					$CertificationValidationCallback = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($CertificationValidationCallbackEncoded))
					# Load required type definition to be able to ignore self-signed certificate to circumvent issues with WebService running with ConfigMgr self-signed certificate binding
					Add-Type -TypeDefinition $CertificationValidationCallback
					[ServerCertificateValidationCallback]::Ignore()
					try {
						# Call WebService endpoint to retrieve package data
						$WebServiceResponse = Invoke-RestMethod -Method Get -Uri $WebServiceUri -Credential $WebServiceEndpoint.Credential -ErrorAction Stop
					}
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to retrieve available package items from WebService endpoint. Error message: $($PSItem.Exception.Message)" -ThrowError }
				}
			}
		}
		# Add returned driver package objects to array list
		if ($null -ne $WebServiceResponse.value) {
			# Construct array object to hold return value
			$PackageArray = New-Object -TypeName System.Collections.ArrayList
			foreach ($Package in $WebServiceResponse.value) { $PackageArray.Add($Package) | Out-Null }
			return $PackageArray
		}
		else { return $null }
	}
	function Get-ComputerData {
		Write-CMLogEntry -Value "[ComputerData]: Starting environment prerequisite checker"
		# Gather computer details based upon specific computer Manufacturer
		$ModelClass = "Win32_ComputerSystem"
		$ModelProp = "Model"
		$SkuClass = "MS_SystemInformation"
		$SkuProp = "BaseBoardProduct"
		# prevent matching with empty string in Confirm-MDMPackage function
		$FallbackSKU = "None"
		$OSVersionFallback = "None"
		if (-not ($PSBoundParameters.ContainsKey('Manufacturer'))) { 
			$ComputerSystem = Get-CimInstance -Class $ModelClass
			$Manufacturer = $ComputerSystem.Manufacturer
		}
		else { $Manufacturer = $PSBoundParameters['Manufacturer'] }
		switch -Wildcard ($Manufacturer) {
			"*Microsoft*" {
				if ($ComputerSystem.Model -match "virtual") {
					# this is a HyperV machine
					$ModelClass = "Win32_ComputerSystemProduct"
					$ModelProp = "Version"
					$PSBoundParameters.Add("SystemSKU", "VM")
				}
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
				[string]$OEMString = Get-CimInstance -Class $ModelClass | Select-Object -ExpandProperty OEMStringArray
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
			"VMWare" {
				$Manufacturer = "VMWare, Inc."
				$ModelClass = "Win32_ComputerSystemProduct"
				$ModelProp = "Version"
				$PSBoundParameters.Add("SystemSKU", "VM")
			}
			"VirtualBox" {
				$Manufacturer = "Oracle"
				$ModelClass = "Win32_ComputerSystemProduct"
				$ModelProp = "Version"
				$PSBoundParameters.Add("SystemSKU", "VM")
			}
			"HyperV" {
				$Manufacturer = "Microsoft"
				$ModelClass = "Win32_ComputerSystemProduct"
				$ModelProp = "Version"
				$PSBoundParameters.Add("SystemSKU", "VM")
			}
			default { if (-not $DebugMode.IsPresent) { New-ErrorRecord -Message ([string]::Empty) -ThrowError } }
		}
		#if not explicitly defined via param then set computer data value(s)
		if (-not ($PSBoundParameters.ContainsKey('ComputerModel'))) {
			$ComputerModel = (Get-CimInstance -ClassName $ModelClass | Select-Object -ExpandProperty $ModelProp)
		}
		else { $ComputerModel = $PSBoundParameters['ComputerModel'] }
		if (-not ($PSBoundParameters.ContainsKey('SystemSKU'))) {
			$SystemSKU = (Get-CimInstance -ClassName $SkuClass | Select-Object -ExpandProperty $SkuProp)
			if ($Manufacturer -eq "Lenovo") { $SystemSKU = $SystemSKU.Substring(0, 4) }
		}
		else { $SystemSKU = $PSBoundParameters['SystemSku'] }
		if (-not ($PSBoundParameters.ContainsKey('OSVersion'))) {
			[System.Version]$OSBuild = (Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty Version)
			$OSVersion = $script:OsBuildVersions[$($OSBuild.Build).ToString()]
		}
		else { $OSVersion = $PSBoundParameters['OSVersion'] }
		if (-not ($PSBoundParameters.ContainsKey('OSArchitecture'))) {
			$Architecture = (Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty OSArchitecture)
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
		else { $OSArchitecture = $PSBoundParameters['OSArchitecture'] }
		if (-not ($PSBoundParameters.ContainsKey('OSVersionFallback')) -and $UseFallbackPackage.IsPresent) {
			#filter hashtable where buildnumbers are less than OSversion and select value from last entry to return the latest previous buildnumber
			$OSVersionFallback = $script:OsBuildVersions.GetEnumerator() | Sort-Object Name | Where-Object { $_.Value -lt $OSVersion } | Select-Object -Last 1 -ExpandProperty Value
		}
		else { $OSVersionFallback = $PSBoundParameters['OSVersionFallback'] }
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
		Write-CMLogEntry -Value "[ComputerData]: Completed environment prerequisite checker"
		# Handle return value from function
		return $ComputerDetails
	}
	function Get-MDMPackages {
		[CmdletBinding(DefaultParameterSetName = "WebService")]
		param(
			[PSCustomObject]$ComputerData,
			[parameter(Mandatory, ParameterSetName = "WebService")]
			[switch]$FallBack,
			[parameter(Mandatory, ParameterSetName = "WebService")]
			[pscustomobject]$WebService,
			[parameter(Mandatory, ParameterSetName = "WebService")]
			[pscustomobject]$UrlResource,
			[parameter(Mandatory, ParameterSetName = "XML")]
			[System.IO.FileInfo]$XMLFilePath
		)
		Write-CMLogEntry -Value "[MDMPackage]: Starting MDM package retrieval using $($PSCmdLet.ParameterSetName) as query source."
		try {
			switch ($PSCmdLet.ParameterSetName) {
				"XML" { $Packages = @((([xml]$(Get-Content -Path $XMLFilePath -Raw)).ArrayOfCMPackage).CMPackage) | Where-Object { $_.Name -match $Filter } }
				"WebService" { $Packages = @(Get-MDMWebServiceItem -Resource $UrlResource -WebServiceEndpoint $WebService ) }
			}#switch
			switch ($OperationalMode) {
				"Production" { $Packages = $Packages | Where-Object { $_.Name -notmatch "Pilot|Legacy|Retired" } }
				"Pilot" { $Packages = $Packages | Where-Object { $_.Name -match "Pilot" } }
			}#switch
		}
		catch [System.Exception] {
			New-ErrorRecord -Message " - An error occurred while retrieving available MDM packages. Error message: $($_.Exception.Message)" -ThrowError
		}
		# Match detected MDM packages from webservice call with computer details and OS image details gathered previously
		$Packages = Confirm-MDMPackage -ComputerData $ComputerData -MDMPackage $Packages -OSVersionFallback:$FallBack
		switch ($Packages.Count) {
			0 {
				if ($FallBack.IsPresent) { $Packages = Get-MDMPackages -ComputerData $ComputerData -WebService $WebService -UrlResource "/SMS_Package?`$filter=contains(Name,'$($Filter) Fallback Package')" }
				else { New-ErrorRecord -Message " - No $($OperationalMode) MDM packages retrieved from $($PSCmdLet.ParameterSetName)." -ThrowError }
			}
			1 { Write-CMLogEntry -Value " - Successfully completed validation with a single $($OperationalMode) MDM package, script execution is allowed to continue" }
			default { Write-CMLogEntry -Value " - Retrieved a total of $($Packages.Count) <$($OperationalMode)> MDM packages from $($PSCmdLet.ParameterSetName) as query source" }
		}
		return $Packages
	}
	function Confirm-MDMPackage {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the computer details object from Get-ComputerData function.")]
			[PSCustomObject]$ComputerData,
			[parameter(Mandatory, HelpMessage = "Specify the MDM package object to be validated.")]
			[System.Object[]]$MDMPackages,
			[parameter(HelpMessage = "Check for MDM packages that match previous versions of Windows.")]
			[switch]$OSVersionFallback
		)
		Write-CMLogEntry -Value "[MDMPackageConfirm]: Starting MDM package matching phase"
		[System.Collections.ArrayList]$MDMPackagesList = @()
		foreach ($MDMPackage in $MDMPackages) {
			# initiate and empty variables for holding custom object values
			$Model = $Architecture = $OSName = $OSVersion = $SystemSKU = ""
			# - HP computer models require the manufacturer name to be a part of the model name, other manufacturers do not
			try {
				switch ($MDMPackage.Manufacturer) {
					{ @("Hewlett-Packard", "HP") -contains $_ } { $Model = $MDMPackage.Name.Replace("Hewlett-Packard", "HP") }
					default { $Model = $MDMPackage.Name.Replace($MDMPackage.Manufacturer, "") }
				}
				$Model = $Model.Replace(" - ", ":").Split(":").Trim()[1]
			}
			catch [System.Exception] { Write-CMLogEntry -Value "Failed. Error: $($_.Exception.Message)" -Severity 3 }
			# fill up variables with regex matching results
			switch -Regex ($MDMPackage.Name) {
				"^.*(?<Architecture>(x86|x64)).*" { $Architecture = $Matches.Architecture }
				"^.*Windows.*(?<OSName>(10)).*" { $OSName = -join @("Windows ", $Matches.OSName) }
				"^.*Windows.*(?<OSVersion>(\d){4}).*" { $OSVersion = $Matches.OSVersion }
			}
			# retrieve SystemSKU from non-empty description field of MDM package
			try { $SystemSKU = [string]$MDMPackage.Description.Split(":").Replace("(", "").Replace(")", "")[1] }
			catch { $SystemSKU = "" }
			# using logical operators for validation of MDM package compliancy with computer data fields
			# watch out when matching against an empty string or $Null -> returns True
			$OSNameMatch = ($OSName -eq $ComputerData.OSName)
			$OSVersionMatch = ($OSVersion -eq $ComputerData.OSVersion)
			if (-not $OSVersionMatch -and $OSVersionFallback.IsPresent) { $OSVersionMatch = ($OSVersion -eq $ComputerData.FallBackOSVersion) }
			$OSArchitectureMatch = ($Architecture -eq $ComputerData.Architecture)
			$ManufacturerMatch = ($MDMPackage.Manufacturer -like $ComputerData.Manufacturer)
			$ComputerModelMatch = ($Model -like $ComputerData.Model)
			# use correct Computer SKU match in debug string
			$CompSKU = $ComputerData.SystemSKU
			$SystemSKUMatch = ($SystemSKU -match $ComputerData.SystemSKU)
			if (-not $SystemSKUMatch) {
				$CompSKU = $ComputerData.FallbackSKU
				$SystemSKUMatch = ($SystemSKU -match $ComputerData.FallbackSKU)
			}
			#all matches must be true to confirm this driver package, grouping boolean operators allows pretty awesome validation rules :-)
			[bool]$DetectionMethodResult = ($OSNameMatch -band $OSVersionMatch -band $OSArchitectureMatch -band $ManufacturerMatch -band $ComputerModelMatch -band $SystemSKUMatch)
			if ($DetectionMethodResult) {
				$DriverPackageDetails = [PSCustomObject]@{
					PackageName    = $MDMPackage.Name
					PackageID      = $MDMPackage.PackageID
					PackageVersion = $MDMPackage.Version
					DateCreated    = $MDMPackage.SourceDate
					Manufacturer   = $MDMPackage.Manufacturer
					Model          = $Model
					SystemSKU      = $SystemSKU
					OSName         = $OSName
					OSVersion      = $OSVersion
					Architecture   = $Architecture
				}
				$MDMPackagesList.Add($DriverPackageDetails) | Out-Null 
			}
			else {
				if ($DebugMode.IsPresent) {
					Write-CMLogEntry -Value "MDM Package $($MDMPackage.PackageID) - $($MDMPackage.Name) did not match with $($ComputerData.Manufacturer) $($ComputerData.Model) $($CompSKU) - $($ComputerData.OSName) $($ComputerData.OSVersion) $($ComputerData.Architecture)."
				}
			}
		}#foreach MDMPackage
		$MDMPackagesList.Sort()
		Write-CMLogEntry -Value " - Found $($MDMPackagesList.Count) MDM package(s) matching required computer details"
		Write-CMLogEntry -Value "[MDMPackageConfirm]: Completed MDM package matching phase"
		return $MDMPackagesList
	}
	function Invoke-MDMPackageContent {
		param(
			[parameter(Mandatory)][string]$Package
		)
		Write-CMLogEntry -Value "[MDMPackageDownload]: Starting MDM package download phase"
		Write-CMLogEntry -Value " - Attempting to download content files for matched MDM package: $($Package.PackageName)"
		# Depending on current deployment type, attempt to download MDM package content
		#set default cmdlet params and reset value(s) if needed
		$DestinationLocationType = "Custom"
		$DestinationVariableName = "OSDMDMPackage"
		$CustomLocationPath = ""
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
			default { $CustomLocationPath = "%_SMSTSMDataPath%\MDMPackage" }
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
			Write-CMLogEntry -Value " - Starting package content download process in ($($InstallMode)), this might take some time"
			$ReturnCode = Invoke-Executable -FilePath $FilePath
			# Reset SMSTSDownloadRetryCount to 5 after attempted download
			Set-MDMTaskSequenceVariable -TSVariable "SMSTSDownloadRetryCount" -TsValue 5
			# Match on return code
			if ($ReturnCode -ne 0) { New-ErrorRecord -Message " - Failed to download package content with PackageID '$($Package.ID)'. Return code was: $($ReturnCode)" -ThrowError }
		}
		catch [System.Exception] { New-ErrorRecord -Message " - An error occurred while attempting to download package content. Error message: $($_.Exception.Message)" -ThrowError }
		if ($ReturnCode -eq 0) {
			$MDMPackageContentLocation = $Script:TSEnvironment.Value("OSDDriverPackage01")
			Write-CMLogEntry -Value " - MDM package content files was successfully downloaded to: $($MDMPackageContentLocation)"
			# Handle return value for successful download of MDM package content files
			return $MDMPackageContentLocation
		}
		else {
			New-ErrorRecord -Message " - MDM package content download process returned an unhandled exit code: $($ReturnCode)" -ThrowError
		}
		Write-CMLogEntry -Value "[MDMPackageDownload]: Completed MDM package download phase"
	}
	function Install-MDMPackageContent {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the full local path to the downloaded MDM package content.")]
			[ValidateNotNullOrEmpty()]
			[string]$ContentLocation
		)
		Write-CMLogEntry -Value "[MDMPackageInstall]: Starting MDM package install phase"
		# Detect if downloaded package content is a compressed archive that needs to be extracted before installation
		$MDMPackageCompressedFile = Get-ChildItem -Path $ContentLocation -Filter "MDMPackage.*"
		if ($null -ne $MDMPackageCompressedFile) {
			Write-CMLogEntry -Value " - Downloaded package content contains a compressed archive"
			# Detect if compressed format is Windows native zip or 7-Zip exe
			switch -wildcard ($MDMPackageCompressedFile.Name) {
				"*.zip" {
					try {
						Write-CMLogEntry -Value " - Attempting to decompress package content file: $($MDMPackageCompressedFile.Name) to: $($ContentLocation)"
						Expand-Archive -Path $MDMPackageCompressedFile.FullName -DestinationPath $ContentLocation -Force -ErrorAction Stop
						Write-CMLogEntry -Value " - Successfully decompressed package content file"
					}
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to decompress package content file. Error message: $($_.Exception.Message)" -ThrowError }
					try { if (Test-Path -Path $MDMPackageCompressedFile.FullName) { Remove-Item -Path $MDMPackageCompressedFile.FullName -Force -ErrorAction Stop } }
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to remove compressed package content file after decompression. Error message: $($_.Exception.Message)" -ThrowError }
				}
				"*.exe" {
					Write-CMLogEntry -Value " - Attempting to decompress self extracting package: $($MDMPackageCompressedFile.Name) to destinationfolder: $($ContentLocation)"
					$ReturnCode = Invoke-Executable -FilePath $MDMPackageCompressedFile.FullName -Arguments "-o`"$($ContentLocation)`" -y"
					if ($ReturnCode -eq 0) {
						Write-CMLogEntry -Value " - Successfully decompressed package"
						Remove-Item -Path $MDMPackageCompressedFile.FullName -Force -ErrorAction SilentlyContinue
					}
					else { New-ErrorRecord -Message " - The self-extracting package returned an error: $($ReturnCode)" -ThrowError }
				}
				"*.wim" {
					try {
						$MDMPackageMountLocation = Join-Path -Path $ContentLocation -ChildPath "Mount"
						if (-not(Test-Path -Path $MDMPackageMountLocation)) {
							Write-CMLogEntry -Value " - Creating mount location directory: $($MDMPackageMountLocation)"
							New-Item -Path $MDMPackageMountLocation -ItemType "Directory" -Force | Out-Null
						}
					}
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to create mount location for WIM file. Error message: $($_.Exception.Message)" -ThrowError }
					try {
						Write-CMLogEntry -Value " - Attempting to mount package content WIM file: $($MDMPackageCompressedFile.Name) at: $($MDMPackageMountLocation)"
						Mount-WindowsImage -ImagePath $MDMPackageCompressedFile.FullName -Path $MDMPackageMountLocation -Index 1 -ErrorAction Stop
						Write-CMLogEntry -Value " - Successfully mounted package content WIM file"
						Write-CMLogEntry -Value " - Copying items from mount directory..."
						Get-ChildItem -Path	$MDMPackageMountLocation | Copy-Item -Destination $ContentLocation -Recurse -Container
					}
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to mount package content WIM file. Error message: $($_.Exception.Message)" -ThrowError }
				}
			}#MDMPackageCompressedFile.Name
			switch ($DeploymentType) {
				"BareMetal" {
					switch ($Filter) {
						"Driver" {
							# Apply installation recursively from downloaded package location
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
						"BIOS" {
							#ToDo
						}
					}#Filter
				}#BareMetal
				"OSUpgrade" {
					# For OSUpgrade, don't attempt to install as this is handled by setup.exe when used together with OSDUpgradeStagedContent
					Write-CMLogEntry -Value " - MDM package content downloaded successfully and located in: $($ContentLocation)"
					Set-MDMTaskSequenceVariable -TSVariable "OSDUpgradeStagedContent" -TsValue $ContentLocation
					Write-CMLogEntry -Value " - Successfully completed MDM package staging process"
				}
				"SystemUpdate" {
					switch ($Filter) {
						"Driver" {
							# Apply drivers recursively from downloaded driver package location
							Write-CMLogEntry -Value " - Driver package content downloaded successfully, attempting to apply drivers using pnputil.exe located in: $($ContentLocation)"
							$ApplyDriverInvocation = Invoke-Executable -FilePath "powershell.exe" -Arguments "pnputil /add-driver $(Join-Path -Path $ContentLocation -ChildPath '*.inf') /subdirs /install | Out-File -FilePath (Join-Path -Path $($LogsDirectory) -ChildPath 'Install-Drivers.txt') -Force"
							Write-CMLogEntry -Value " - Successfully installed drivers"
						}
						"BIOS" {
							#ToDo
						}
					}
				}
				"PreCache" { Write-CMLogEntry -Value " - MDM package content successfully downloaded and pre-cached to: $($ContentLocation)" }
			}#DeploymentType
			# Cleanup potential compressed driver package content
			switch -wildcard ($MDMPackageCompressedFile.Name) {
				"*.wim" {
					try {
						# Attempt to dismount compressed driver package content WIM file
						Write-CMLogEntry -Value " - Attempting to dismount MDM package content WIM file: $($MDMPackageCompressedFile.Name) at $($MDMPackageMountLocation)"
						Dismount-WindowsImage -Path $MDMPackageMountLocation -Discard -ErrorAction Stop
						Write-CMLogEntry -Value " - Successfully dismounted MDM package content WIM file"
					}
					catch [System.Exception] {
						New-ErrorRecord -Message " - Failed to dismount MDM package content WIM file. Error message: $($_.Exception.Message)" -ThrowError
					}
				}
			}
		}
	}
}#begin

End {
	if ($DebugMode.IsPresent) { Write-CMLogEntry -Value " - Apply MDM Package script has successfully completed in <debug mode>" }
	# Reset OSDDownloadContent.exe dependant variables before next task sequence step
	else { @("OSDDownloadDownloadPackages", "OSDDownloadDestinationLocationType", "OSDDownloadDestinationVariable", "OSDDownloadDestinationPath") | ForEach-Object { Set-MDMTaskSequenceVariable -TSVariable $_ } }
	Write-CMLogEntry -Value "[InvokeMDMPackage]: Completed Apply MDM Package process"
	# Write final output to log file
	Out-File -FilePath $LogFilePath -InputObject $script:LogEntries -Encoding default -NoClobber -Force
}
