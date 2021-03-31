<#
.SYNOPSIS
Download MDM driver package (regular package) matching computer model, manufacturer and operating system.
.DESCRIPTION
This script will determine the manufacturer, model/type, architecture and operating system being deployed to query
the webservice endpoint (or XML file) for a list of packages. It then sets the OSDDownloadDownloadPackages variable
to include the PackageID property of the package(s) matching the computer specs.
.PARAMETER DeploymentType
Set the script to operate in deployment type mode: BareMetal (default), OSUpdate, SystemUpdate or PreCache.
.PARAMETER Endpoint
Specify the fully qualified domain name of the server hosting the webservice, e.g. CM01.domain.local.
.PARAMETER NetworkLocation
Choose if the client is connected to the Intranet (default) or Internet during the Task Sequence
.PARAMETER UserName
Specify the service account user name used for authenticating against the webservice endpoint.
.PARAMETER Password
Specify the service account password used for authenticating against the webservice endpoint.
.PARAMETER ClientID
Specify the Azure ClientID used for authenticating against the CMG webservice endpoint.
.PARAMETER TenantName
Specify the Azure TenantName used for authenticating against the CMG webservice endpoint.
.PARAMETER OSVersion
Define the shorthand operating system version value e.g. '2010' to be used for matching packages.
.PARAMETER FallBackOSVersion
Use this switch to check for MDM packages that match a previous operating system version.
.PARAMETER OSArchitecture
Override the automatically detected operating system architecture e.g. 'x64' (default).
.PARAMETER Manufacturer
Override the automatically detected computer manufacturer: AZW, Dell, Fujitsu, HP, HyperV, Lenovo, Microsoft, Panasonic, VMWare, Viglen, VirtualBox.
.PARAMETER ComputerModel
Override the automatically detected computer model.
.PARAMETER SystemSKU
Override the automatically detected System SKU (Stock Keeping Unit).
.PARAMETER Filter
Define a filter used when calling ConfigMgr WebService to only return packages matching the filter: Driver (default) or BIOS.
.PARAMETER OperationalMode
Choose Production (default) or Pilot to only return packages from the ConfigMgr webservice matching the selected operational mode.
.PARAMETER InstallMode
Specify to install drivers using DISM.exe with recurse option (default) or spawn a new process for each driver.
.PARAMETER QuerySource
Specify to retrieve MDM packages using an XML file or the ConfigMgr webservice (default) as query source.
.PARAMETER UseFallbackPackage
Use this switch to use a custom made generic falback package.
.PARAMETER PreCachePath
Specify a custom path for the PreCache directory, overriding the default CCMCache directory, fallback upon error is local temp folder.
.PARAMETER DebugMode
Set the script to operate in 'DebugMode'for retrieval of MDM packages but without actual download or installation.
.PARAMETER XMLFileName
Option to override (default) name of the XML selection file: MDMPackages.xml
.PARAMETER LogFileName
Option to override default name of the script output logfile (without extension!): InvokeMDMPackage (default)
.EXAMPLE
# Detect, download and apply packages during OS deployment:
.\Invoke-MDMPackage.ps1 -Endpoint "CM01.domain.com" -OSVersion 2010
# Detect, download and apply packages during OS deployment and check for packages that match a previous OS Version:
.\Invoke-MDMPackage.ps1 -DeploymentType BareMetal -Endpoint "CM01.domain.com" -OSVersion 2010 -FallBackOSVersion
# Detect and download packages during OS upgrade:
.\Invoke-MDMPackage.ps1 -DeploymentType OSUpdate -Endpoint "CM01.domain.com" -OSVersion 2010
# Detect, download and update a device with latest packages for a running operating system:
.\Invoke-MDMPackage.ps1 -DeploymentType SystemUpdate -Endpoint "CM01.domain.com"
# Detect and download (pre-caching content) during OS upgrade:
.\Invoke-MDMPackage.ps1 -DeploymentType PreCache -Endpoint "CM01.domain.com" -OSVersion 2010
# Detect and download (pre-caching content) to a custom path during OS upgrade:
.\Invoke-MDMPackage.ps1 -DeploymentType PreCache -Endpoint "CM01.domain.com" -OSVersion 2010 -PreCachePath "$($env:SystemDrive)\MDMpackages"
# Run in a debug mode for testing purposes on the targeted computer model:
.\Invoke-MDMPackage.ps1 -DebugMode -Endpoint "CM01.domain.com" -UserName "svc@domain.com" -Password "svc-password" -OSVersion 2010
# Run in a debug mode for testing purposes overriding the (automatically detected) computer specifications:
.\Invoke-MDMPackage.ps1 -DebugMode -Endpoint "CM01.domain.com" -UserName "svc@domain.com" -Password "svc-password" -OSVersion 2010 -Manufacturer "Lenovo" -ComputerModel "Thinkpad X1 Tablet" -SystemSKU "20KKS7"
# Detect, download and apply packages during OS deployment and use an XML table as the source of MDM package ID's instead of the webservice:
.\Invoke-MDMPackage.ps1 -OSVersion 2010 -FallBackOSVersion -QuerySource XML -XMLFileName "Install32bitDrivers.xml"
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
4.0.9.4 - (2021-02-01) - changed other monikers to more generic descriptions
4.0.9.5 - (2021-03-07) - added newer Windows builds to dynamic param OsBuildVersions
4.1.0.3 - (2021-03-28) - multiple rewrites after fiddling and testing in pre-production, replaced detection of endpoints with mandatory Endpoint script parameter, added some params, added XML output for convenience
4.1.0.4 - (2021-03-30) - corrected some typos, added alias property 'Name' to MDMPackage object, removed param type [string] of MDMPackage in Invoke-MDMPackageContent function as an object is expected
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
	[parameter(HelpMessage = "Specify the deployment type mode for MDM package deployments: 'BareMetal' (= default), 'OSUpdate', 'SystemUpdate' or 'PreCache'.")]
	[ValidateSet("BareMetal", "OSUpdate", "SystemUpdate", "PreCache")]
	[string]$DeploymentType = "BareMetal",
	[parameter(Mandatory, HelpMessage = "Specify the fully qualified domain name of the server hosting a valid webservice, e.g. CM01.domain.local.")]
	[string]$Endpoint,
	[parameter(HelpMessage = "Specify the client's network connection as Intranet (= default) or Internet ")]
	[ValidateSet("Intranet", "Internet")]
	[string]$NetworkLocation = "Intranet",
	[parameter(HelpMessage = "Specify the service account user name used for authenticating against the endpoint.")]
	[string]$UserName,
	[parameter(HelpMessage = "Specify the service account password used for authenticating against the endpoint.")]
	[string]$Password,
	[parameter(HelpMessage = "Specify the ClientID for authenticating against CMG.")]
	[string]$ClientID,
	[parameter(HelpMessage = "Specify the TenantName for authenticating against CMG.")]
	[string]$TenantName,
	[parameter(HelpMessage = "Use this switch to check for MDM packages that match a previous version of Windows.")]
	[switch]$FallBackOSVersion,
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
	[ValidateNotNullOrEmpty()][string]$XMLFileName = "MDMPackages.xml",
	[parameter(HelpMessage = "Name of the log file (without extension!) for script output: InvokeMDMPackage (= default)")]
	[ValidateNotNullOrEmpty()][string]$LogFileName = "InvokeMDMPackage"
)

DynamicParam {
	# using a dynamic param for validation of script parameter(s) and script variable(s) with just one hashtable to define
	[System.Collections.Hashtable]$script:OsBuildVersions = @{
		"19044" = '2110'
		"19043" = '2105'
		"19042" = '2010'
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
	$ParameterAttribute.HelpMessage = "Override the automatically detected (shorthand) OS version, e.g. 2010"
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
	Write-MDMLogEntry -Value "[InvokeMDMPackage]: Apply $($OperationalMode) MDM Package(s) initiated in $($DeploymentType) deployment mode using script version $($ScriptVersion)."
	try {
		# Determine computer OS version, Architecture, Manufacturer, Model, SystemSKU and FallbackSKU
		$ComputerData = Get-ComputerData -Manufacturer $Manufacturer -ComputerModel $ComputerModel -SystemSKU $SystemSKU -OSVersion $OSVersion -OSArchitecture $OSArchitecture
		#Resolve, validate, test and authenticate the MDM webservice
		$WebService = Get-MDMWebService -UserName $UserName -Password $Password -Endpoint $Endpoint -ClientID $ClientID -TenantName $TenantName
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
			Write-MDMLogEntry -Value "[MDMPackageInstall]: Completed MDM package install phase"
		}
	}
	catch [System.Exception] {
		New-ErrorRecord -Message "[InvokeMDMPackage]: Apply MDM Package process failed, please refer to previous error or warning messages"
		Out-File -FilePath $LogFilePath -InputObject $script:LogEntries -Encoding default -NoClobber -Force
		# Main try-catch block was triggered, this should cause the script to fail with exit code 1
		exit 1
	}
}#process

Begin {
	[version]$ScriptVersion = "4.1.0.4"
	$LogsDirectory = $env:TEMP
	try {
		$Script:TSEnvironment = New-Object -ComObject "Microsoft.SMS.TSEnvironment"
		$LogsDirectory = $Script:TSEnvironment.Value("_SMSTSLogPath")
	}
	catch [System.Exception] { Write-Warning -Message "Script is not running in a Task Sequence" }
	$Now = Get-Date -Format "MM-dd-yyyy_HHumm"
	$LogFileName = $LogFileName, $Filter, $Now, ".log" -join "_"
	$LogFilePath = Join-Path -Path $LogsDirectory -ChildPath $LogFileName
	[System.Collections.ArrayList]$script:LogEntries = @()
	# Set script error preference variable
	$ErrorActionPreference = "Stop"

	# Functions
	function Write-MDMLogEntry {
		param (
			[parameter(Mandatory, HelpMessage = "Value added to the log file.")]
			[ValidateNotNullOrEmpty()]
			[string]$Value,
			[parameter(HelpMessage = "Severity for the log entry. 1 for Informational (default), 2 for Warning and 3 for Error.")]
			[ValidateSet("1", "2", "3")]
			[int]$Severity = 1
		)
		# Construct time stamp for log entry
		if (-not(Test-Path -Path 'variable:global:TimezoneBias')) {
			[string]$global:TimezoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
			if ($TimezoneBias -match "^-") { $TimezoneBias = $TimezoneBias.Replace('-', '+') }
			else { $TimezoneBias = '-' + $TimezoneBias }
		}
		# Construct date for log entry
		$Now = Get-Date
		$Time = -join @($Now.ToString("HH:mm:ss.fff"), $TimezoneBias)
		$Date = $Now.ToString("MM-dd-yyyy")
		# Construct context for log entry
		$Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
		# Construct final log entry
		$LogEntry = "<![LOG[{0}]LOG]!><time=""{1}"" date=""{2}"" component=""InvokeMDMPackage"" context=""{3}"" type=""{4}"" thread=""{5}"" file=""{6}"">" -f $Value, $Time, $Date, $Context, $Severity, $PID, $File
		$script:LogEntries.Add($LogEntry) | Out-Null
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
		Write-MDMLogEntry -Value $Message -Severity 3
		# Construct new error record to be returned from function based on parameter inputs
		$SystemException = New-Object -TypeName $Exception -ArgumentList ([string]::Empty)
		$ErrorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList @($SystemException, $ErrorID, $ErrorCategory, $TargetObject)
		if ($ThrowError.IsPresent) { $PSCmdlet.ThrowTerminatingError($ErrorRecord) }
		# Handle return value
		return $ErrorRecord
	}
	function Get-ComputerData {
		param(
			[string]$Manufacturer,
			[string]$ComputerModel,
			[string]$SystemSKU,
			[string]$OSVersion,
			[string]$OSArchitecture
		)
		Write-MDMLogEntry -Value "[ComputerData]: Starting environment prerequisite checker"
		# Gather computer details based upon specific computer Manufacturer
		$ModelClass = "Win32_ComputerSystem"
		$ModelProp = "Model"
		$SkuClass = "MS_SystemInformation"
		$SkuProp = "BaseBoardProduct"
		# prevent matching with empty string in Confirm-MDMPackage function
		$FallbackSKU = "None"
		$PreviousOSVersion = "None"
		if ([string]::IsNullOrEmpty($Manufacturer)) { 
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
		if ([string]::IsNullOrEmpty($ComputerModel)) {
			$ComputerModel = (Get-CimInstance -ClassName $ModelClass | Select-Object -ExpandProperty $ModelProp)
		}
		else { $ComputerModel = $PSBoundParameters['ComputerModel'] }
		if ([string]::IsNullOrEmpty($SystemSKU)) {
			$SystemSKU = (Get-CimInstance -ClassName $SkuClass | Select-Object -ExpandProperty $SkuProp)
			if ($Manufacturer -eq "Lenovo") { $SystemSKU = $SystemSKU.Substring(0, 4) }
		}
		else { $SystemSKU = $PSBoundParameters['SystemSku'] }
		if ([string]::IsNullOrEmpty($OSVersion)) {
			[System.Version]$OSBuild = (Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty Version)
			$OSVersion = $script:OsBuildVersions[$($OSBuild.Build).ToString()]
		}
		else { $OSVersion = $PSBoundParameters['OSVersion'] }
		if ([string]::IsNullOrEmpty($OSArchitecture)) {
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
		if ($FallBackOSVersion.IsPresent) {
			#filter hashtable where buildnumbers are less than OSversion and select value from last entry to return the latest previous buildnumber
			$PreviousOSVersion = $script:OsBuildVersions.GetEnumerator() | Sort-Object Name | Where-Object { $_.Value -lt $OSVersion } | Select-Object -Last 1 -ExpandProperty Value
		}
		# Handle output to log file for computer details
		Write-MDMLogEntry -Value " - Computer manufacturer determined as: $($Manufacturer)"
		Write-MDMLogEntry -Value " - Computer model determined as: $($ComputerModel)"
		Write-MDMLogEntry -Value " - Computer SystemSKU determined as: $($SystemSKU)"
		Write-MDMLogEntry -Value " - Computer Fallback SystemSKU determined as: $($FallBackSKU)"
		Write-MDMLogEntry -Value " - Target operating system name configured as: Windows 10"
		Write-MDMLogEntry -Value " - Target operating system architecture configured as: $($OSArchitecture)"
		Write-MDMLogEntry -Value " - Target operating system version configured as: $($OSVersion)"
		# Create a custom object for computer details gathered from local WMI
		$ComputerDetails = [PSCustomObject]@{
			OSName            = "Windows 10"
			OSVersion         = $OSVersion
			FallBackOSVersion = $PreviousOSVersion
			Architecture      = $OSArchitecture
			Manufacturer      = $Manufacturer
			Model             = $ComputerModel
			SystemSKU         = $SystemSKU
			FallbackSKU       = $FallBackSKU
		}
		Write-MDMLogEntry -Value "[ComputerData]: Completed environment prerequisite checker"
		# Handle return value from function
		return $ComputerDetails
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
		Write-MDMLogEntry -Value " - Setting task sequence variable $($TSVariable) to: $($TsValue) "
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
	function ConvertTo-XmlQueryFile {
		param($MDMPackageList)
		[xml]$doc = New-Object System.Xml.XmlDocument
		#Add XML Declaration, root Node and child tree of packages
		$doc.AppendChild($doc.CreateXmlDeclaration("1.0", "UTF-8", $null)) | Out-Null
		$root = $doc.AppendChild($doc.CreateElement("MDMPackages"))
		$MDMPackageList | ForEach-Object {
			$childobj = $root.AppendChild($doc.CreateElement("MDMPackage"))
			$childobj.SetAttribute("PackageID", $_.PackageID)
			$childobj.SetAttribute("Name", $_.PackageName)
			$childobj.SetAttribute("Description", $_.Description)
			$childobj.SetAttribute("Manufacturer", $_.Manufacturer)
		}
		return $doc.outerxml
	}
	function Get-MDMWebService {
		param(
			[string]$UserName,
			[string]$Password,
			[string]$Endpoint,
			[string]$ClientID,
			[string]$TenantName
		)
		Write-MDMLogEntry -Value "[WebService]: Starting endpoint validation phase"
		# Validation of service account credentials set via TS environment variables or script parameter input, empty string will throw an error in ConvertTo-ObfuscatedString function
		if ([string]::IsNullOrEmpty($UserName)) {
			try { $UserName = $Script:TSEnvironment.Value("SMSTSRunPowerShellUserName") } catch { $UserName = "" }
			if ([string]::IsNullOrEmpty($UserName)) { 
				try { $UserName = $Script:TSEnvironment.Value("MDMUserName") } catch { $UserName = "" }
			}
		}
		else { $UserName = $PSBoundParameters['UserName'] }
		try {
			$ObfuscatedUserName = ConvertTo-ObfuscatedString -InputObject $UserName
			Write-MDMLogEntry -Value " - Successfully read service account username: $($ObfuscatedUserName)"
		}
		catch {
			if ($DebugMode.IsPresent) { New-ErrorRecord -Message " - Service account username could not be determined from parameter input" -ThrowError }
			else { New-ErrorRecord -Message " - Required service account username could not be determined from TS environment" -ThrowError }
		}
		if ([string]::IsNullOrEmpty($Password)) {
			try { $Password = $Script:TSEnvironment.Value("SMSTSRunPowerShellUserPassword") } catch { $Password = "" }
			if ([string]::IsNullOrEmpty($Password)) { 
				try { $Password = $Script:TSEnvironment.Value("MDMPassword") } catch { $Password = "" }
			}
		}
		else { $Password = $PSBoundParameters['Password'] }
		try {
			$ObfuscatedPassword = ConvertTo-ObfuscatedString -InputObject $Password
			if ($DebugMode.IsPresent) { Write-MDMLogEntry -Value " - Successfully read service account password: $($ObfuscatedPassword)" }
			else { Write-MDMLogEntry -Value " - Successfully read service account password: ********" }
		}
		catch {
			if ($DebugMode.IsPresent) { New-ErrorRecord -Message " - Service account password could not be determined from parameter input" -ThrowError }
			else { New-ErrorRecord -Message " - Required service account password could not be determined from TS environment" -ThrowError }
		}
		# Construct PSCredential object for WebService authentication on either Intranet or CMG on Internet
		$Credential = Get-AuthCredential -UserName $UserName -Password $Password
		if ([string]::IsNullOrEmpty($Endpoint)) { New-ErrorRecord -Message " - Required script parameter [Endpoint] for determining Admin service URL was not set" -ThrowError }
		else {
			switch ( $NetworkLocation ) {
				'Internet' {
					Write-MDMLogEntry -Value "Retrieving client identification for CMG webservice"
					if ([string]::IsNullOrEmpty($ClientID)) { 
						try { $ClientID = $Script:TSEnvironment.Value("MDMClientID") } catch { $ClientID = "" }
					} 
					else { $ClientID = $PSBoundParameters['ClientID'] }
					if ([string]::IsNullOrEmpty($TenantName)) { 
						try { $TenantName = $Script:TSEnvironment.Value("MDMTenantName") } catch { $TenantName = "" }
					}
					else { $ClientID = $PSBoundParameters['TenantName'] }
					if (([string]::IsNullOrEmpty($ClientID)) -or ([string]::IsNullOrEmpty($TenantName))) { New-ErrorRecord -Message " - Required ClientID or TenantName could not be retrieved" -ThrowError }
					else { $AuthToken = Get-AuthToken -TenantName $TenantName -ClientID $ClientID -Credential $Credential }
					$WebServiceURL = "{0}/wmi" -f $Endpoint
				}
				'Intranet' {
					$WebServiceURL = "https://{0}/AdminService/wmi" -f $Endpoint
				}
			}#switch
		}
		Write-MDMLogEntry -Value " - WebService endpoint type is: $($NetworkLocation) and can be reached via URL: $($WebServiceURL)"
		$WebServiceEndpoint = [PSCustomObject]@{
			URL        = $WebServiceURL
			Type       = $NetworkLocation
			ClientID   = $ClientID
			TenantName = $TenantName
			AuthToken  = $AuthToken
			Credential = $Credential
		}
		Write-MDMLogEntry -Value "[WebService]: Completed WebService endpoint phase"
		return $WebServiceEndpoint
	}
	function Install-AuthModule {
		param ( $ModuleName = "PSIntuneAuth" )
		# Determine if the PSIntuneAuth module needs to be installed
		try {
			Write-MDMLogEntry -Value " - Attempting to locate $($ModuleName) module"
			$PsModule = Get-InstalledModule -Name $ModuleName -ErrorAction Stop -Verbose:$false
			if ($null -ne $PsModule) {
				Write-MDMLogEntry -Value " - $($ModuleName) module detected, checking for latest version"
				$LatestModuleVersion = (Find-Module -Name $ModuleName -ErrorAction SilentlyContinue -Verbose:$false).Version
				if ($LatestModuleVersion -gt $PsModule.Version) {
					Write-MDMLogEntry -Value " - Latest version of $($ModuleName) module is not installed, attempting to install: $($LatestModuleVersion.ToString())"
					$UpdateModuleInvocation = Update-Module -Name $ModuleName -Scope CurrentUser -Force -ErrorAction Stop -Confirm:$false -Verbose:$false
				}
			}
		}
		catch [System.Exception] {
			Write-MDMLogEntry -Value " - Unable to detect $($ModuleName) module, attempting to install from PSGallery" -Severity 2
			try {
				Install-PackageProvider -Name "NuGet" -Force -Verbose:$false
				Install-Module -Name $ModuleName -Scope AllUsers -Force -ErrorAction Stop -Confirm:$false -Verbose:$false
				Write-MDMLogEntry -Value " - Successfully installed $($ModuleName) module"
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
			Install-AuthModule -ModuleName "PSIntuneAuth"
			# Retrieve authentication token
			Write-MDMLogEntry -Value " - Attempting to retrieve authentication token using native client with ID: $($ClientID)"
			$AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName -ClientID $ClientID -Credential $Credential -Resource "https://ConfigMgrService" -RedirectUri "https://login.microsoftonline.com/common/oauth2/nativeclient" -ErrorAction Stop
			Write-MDMLogEntry -Value " - Successfully retrieved CMG authentication token"
			return $AuthToken
		}
		catch [System.Exception] { New-ErrorRecord -Message " - Failed to retrieve CMG authentication token. Error message: $($PSItem.Exception.Message)" -ThrowError }
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
		Write-MDMLogEntry -Value " - Calling WebService endpoint with URI: $($WebServiceUri)"
		switch ($WebServiceEndpoint.Type) {
			"Internet" {
				try { $WebServiceResponse = Invoke-RestMethod -Method Get -Uri $WebServiceUri -Headers $WebServiceEndpoint.AuthToken -ErrorAction Stop }
				catch [System.Exception] { New-ErrorRecord -Message " - Failed to retrieve available package items from WebService endpoint. Error message: $($PSItem.Exception.Message)" -ThrowError }
			}
			"Intranet" {
				try { $WebServiceResponse = Invoke-RestMethod -Method Get -Uri $WebServiceUri -Credential $WebServiceEndpoint.Credential -ErrorAction Stop	}
				catch [System.Security.Authentication.AuthenticationException] {
					Write-MDMLogEntry -Value " - The remote WebService endpoint certificate is invalid according to the validation procedure. Error message: $($PSItem.Exception.Message)" -Severity 2
					Write-MDMLogEntry -Value " - Will attempt to set the current session to ignore self-signed certificates and retry WebService endpoint connection" -Severity 2
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
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to retrieve available package items from WebService endpoint while ignoring self signed certtificate. Error message: $($PSItem.Exception.Message)" -ThrowError }
				}
				catch [System.Exception] { New-ErrorRecord -Message " - Permanent failure while retrieving available package items from WebService endpoint. Error message: $($PSItem.Exception.Message)" -ThrowError }
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
		Write-MDMLogEntry -Value "[MDMPackage]: Starting MDM package retrieval using $($PSCmdLet.ParameterSetName) as query source."
		try {
			switch ($PSCmdLet.ParameterSetName) {
				"XML" { $Packages = @((([xml]$(Get-Content -Path $XMLFilePath -Raw)).MDMPackages).MDMPackage) | Where-Object { $_.Name -match $Filter } }
				"WebService" { $Packages = @(Get-MDMWebServiceItem -Resource $UrlResource -WebServiceEndpoint $WebService ) }
			}#switch
			switch ($OperationalMode) {
				"Production" { $Packages = $Packages | Where-Object { $_.Name -notmatch "Pilot|Legacy|Retired" } }
				"Pilot" { $Packages = $Packages | Where-Object { $_.Name -match "Pilot" } }
			}#switch
		}
		catch [System.Exception] { New-ErrorRecord -Message " - An error occurred while retrieving MDM packages. Error message: $($_.Exception.Message)" -ThrowError }
		# Match detected MDM packages from webservice call with computer details and OS image details gathered previously
		$Packages = @(Confirm-MDMPackage -ComputerData $ComputerData -MDMPackages $Packages)
		switch ($Packages.Count) {
			0 {
				if ($FallBack.IsPresent) { $Packages = Get-MDMPackages -ComputerData $ComputerData -WebService $WebService -UrlResource "/SMS_Package?`$filter=contains(Name,'$($Filter) Fallback Package')" }
				else { New-ErrorRecord -Message " - No matching $($OperationalMode) MDM packages found." }
			}
			1 { Write-MDMLogEntry -Value " - Successfully completed validation with a single $($OperationalMode) MDM package." }
			default { Write-MDMLogEntry -Value " - Retrieved a total of $($Packages.Count) <$($OperationalMode)> MDM packages" }
		}
		return $Packages
	}
	function Confirm-MDMPackage {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the computer details object from Get-ComputerData function.")]
			[PSCustomObject]$ComputerData,
			[parameter(Mandatory, HelpMessage = "Specify the MDM package object to be validated.")]
			[System.Object[]]$MDMPackages
		)
		Write-MDMLogEntry -Value "[MDMPackageConfirm]: Starting MDM package matching phase"
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
			catch [System.Exception] { Write-MDMLogEntry -Value "Failed parsing MDM package $($MDMPackage.PackageID). Error: $($_.Exception.Message)" -Severity 3 }
			# fill up variables with regex matching results
			switch -Regex ($MDMPackage.Name) {
				"^.*(?<Architecture>(x86|x64)).*" { $Architecture = $Matches.Architecture }
				"^.*Windows.*(?<OSName>(10)).*" { $OSName = -join @("Windows ", $Matches.OSName) }
				"^.*Windows.*(?<OSVersion>(\d){4}).*" { $OSVersion = $Matches.OSVersion }
			}
			# retrieve SystemSKU from non-empty description field of MDM package
			try { $SystemSKU = ([string]$MDMPackage.Description -Replace "\(|\)", "").Split(":")[1] }
			catch { $SystemSKU = "" }
			# using logical operators for validation of MDM package compliancy with computer data fields
			# watch out when matching against an empty string or $Null -> returns True
			$OSNameMatch = ($OSName -eq $ComputerData.OSName)
			# give back warning in log if OSversion is not found and allow installation of MDM package just the same
			# maybe somewhat controversial but counting on Windows to select/filter drivers based on PNP ID's
			$OSVersionMatch = ($OSVersion -eq $ComputerData.OSVersion)
			if (-not $OSVersionMatch -and $OSVersionFallback.IsPresent) { $OSVersionMatch = ($OSVersion -eq $ComputerData.FallBackOSVersion) }
			if (-not $OSVersionMatch) { $OSVersionMatch = $true }
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
			$MDMPackageInfo = "MDM Package: $($MDMPackage.PackageID) - $($MDMPackage.Name)"
			$CompDataInfo = "Computer Info: $($ComputerData.Manufacturer) $($ComputerData.Model) $($CompSKU) - $($ComputerData.OSName) $($ComputerData.Architecture) - $($ComputerData.OSVersion)"
			if ($DetectionMethodResult) {
				Write-MDMLogEntry -Value "Debug - $($MDMPackageInfo) MATCHED with $($CompDataInfo)."
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
				$DriverPackageDetails | Add-Member -MemberType AliasProperty -Name Name -Value PackageName
				$DriverPackageDetails | Add-Member -MemberType AliasProperty -Name ID -Value PackageID
				$MDMPackagesList.Add($DriverPackageDetails) | Out-Null
			}
			else { if ($DebugMode.IsPresent) { Write-MDMLogEntry -Value "Debug - $($MDMPackageInfo) did NOT match with $($CompDataInfo)." -Severity 2 } }
		}#foreach MDMPackage
		$MDMPackagesList.Sort()
		Write-MDMLogEntry -Value " - Found $($MDMPackagesList.Count) MDM package(s) matching required computer details"
		Write-MDMLogEntry -Value "[MDMPackageConfirm]: Completed MDM package matching phase"
		return $MDMPackagesList
	}
	function Invoke-MDMPackageContent {
		param(
			[parameter(Mandatory)]$Package
		)
		Write-MDMLogEntry -Value "[MDMPackageDownload]: Starting MDM package download phase"
		Write-MDMLogEntry -Value " - Attempting to download content files for matched MDM package: ($($Package.PackageID)) - $($Package.PackageName)"
		# Depending on current deployment type, attempt to download MDM package content
		#set default cmdlet params and reset value(s) if needed
		$DestinationLocationType = "Custom"
		$DestinationVariableName = "OSDMDMPackage"
		$CustomLocationPath = ""
		switch ($DeploymentType) {
			"PreCache" {
				if ([string]::IsNullOrEmpty($PreCachePath)) { $DestinationLocationType = "CCMCache" }
				else {
					while (-not (Test-Path -Path $PreCachePath)) {
						Write-MDMLogEntry -Value " - Attempting to create PreCachePath directory, as it doesn't exist (yet): $($PreCachePath)"
						try { New-Item -Path $PreCachePath -ItemType Directory -Force -ErrorAction Stop | Out-Null }
						catch [System.Exception] {
							New-ErrorRecord -Message " - Failed to create PreCachePath directory '$($PreCachePath)'. Error message: $($_.Exception.Message)" -ThrowError
							$PreCachePath = $env:TEMP
						}
					}
					$CustomLocationPath = $PreCachePath
				}
			}
			default { $CustomLocationPath = "%_SMSTSMDataPath%\MDMPackage" }
		}#switch
		#setting various TS variables
		Set-MDMTaskSequenceVariable -TSVariable "OSDDownloadDownloadPackages" -TsValue $Package.PackageID
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
			Write-MDMLogEntry -Value " - Starting package content download process in [$($InstallMode)], this might take some time"
			$ReturnCode = Invoke-Executable -FilePath $FilePath
			# Reset SMSTSDownloadRetryCount to 5 after attempted download
			Set-MDMTaskSequenceVariable -TSVariable "SMSTSDownloadRetryCount" -TsValue 5
			# Match on return code
			switch ($ReturnCode) {
				0 {
					$MDMPackageContentLocation = $Script:TSEnvironment.Value("OSDMDMPackage01")
					Write-MDMLogEntry -Value " - MDM package content files was successfully downloaded to: $($MDMPackageContentLocation)"
					# Handle return value for successful download of MDM package content files
					return $MDMPackageContentLocation
				}
				default { New-ErrorRecord -Message " - MDM package content download process returned an unhandled exit code: $($ReturnCode)" -ThrowError }
			}#switch
		}
		catch [System.Exception] { New-ErrorRecord -Message " - An error occurred while attempting to download package content. Error message: $($_.Exception.Message)" -ThrowError }
		Write-MDMLogEntry -Value "[MDMPackageDownload]: Completed MDM package download phase"
	}
	function Install-MDMPackageContent {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the full local path to the downloaded MDM package content.")]
			[ValidateNotNullOrEmpty()]
			[string]$ContentLocation
		)
		Write-MDMLogEntry -Value "[MDMPackageInstall]: Starting MDM package install phase"
		# Detect if downloaded package content is a compressed archive that needs to be extracted before installation
		$MDMPackageCompressedFile = Get-ChildItem -Path $ContentLocation -Filter "MDMPackage.*"
		if ($null -ne $MDMPackageCompressedFile) {
			Write-MDMLogEntry -Value " - Downloaded package content contains a compressed archive"
			# Detect if compressed format is Windows native zip or 7-Zip exe
			switch -wildcard ($MDMPackageCompressedFile.Name) {
				"*.zip" {
					try {
						Write-MDMLogEntry -Value " - Attempting to decompress package content file: $($MDMPackageCompressedFile.Name) to: $($ContentLocation)"
						Expand-Archive -Path $MDMPackageCompressedFile.FullName -DestinationPath $ContentLocation -Force -ErrorAction Stop
						Write-MDMLogEntry -Value " - Successfully decompressed package content file"
					}
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to decompress package content file. Error message: $($_.Exception.Message)" -ThrowError }
					try { if (Test-Path -Path $MDMPackageCompressedFile.FullName) { Remove-Item -Path $MDMPackageCompressedFile.FullName -Force -ErrorAction Stop } }
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to remove compressed package content file after decompression. Error message: $($_.Exception.Message)" -ThrowError }
				}
				"*.exe" {
					Write-MDMLogEntry -Value " - Attempting to decompress self extracting package: $($MDMPackageCompressedFile.Name) to destinationfolder: $($ContentLocation)"
					$ReturnCode = Invoke-Executable -FilePath $MDMPackageCompressedFile.FullName -Arguments "-o`"$($ContentLocation)`" -y"
					if ($ReturnCode -eq 0) {
						Write-MDMLogEntry -Value " - Successfully decompressed package"
						Remove-Item -Path $MDMPackageCompressedFile.FullName -Force -ErrorAction SilentlyContinue
					}
					else { New-ErrorRecord -Message " - The self-extracting package returned an error: $($ReturnCode)" -ThrowError }
				}
				"*.wim" {
					try {
						$MDMPackageMountLocation = Join-Path -Path $ContentLocation -ChildPath "Mount"
						if (-not(Test-Path -Path $MDMPackageMountLocation)) {
							Write-MDMLogEntry -Value " - Creating mount location directory: $($MDMPackageMountLocation)"
							New-Item -Path $MDMPackageMountLocation -ItemType "Directory" -Force | Out-Null
						}
					}
					catch [System.Exception] { New-ErrorRecord -Message " - Failed to create mount location for WIM file. Error message: $($_.Exception.Message)" -ThrowError }
					try {
						Write-MDMLogEntry -Value " - Attempting to mount package content WIM file: $($MDMPackageCompressedFile.Name) at: $($MDMPackageMountLocation)"
						Mount-WindowsImage -ImagePath $MDMPackageCompressedFile.FullName -Path $MDMPackageMountLocation -Index 1 -ErrorAction Stop
						Write-MDMLogEntry -Value " - Successfully mounted package content WIM file"
						Write-MDMLogEntry -Value " - Copying items from mount directory..."
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
							Write-MDMLogEntry -Value " - Attempting to apply drivers using dism.exe located in: $($ContentLocation)"
							# Determine driver injection method from parameter input
							Write-MDMLogEntry -Value " - DriverInstallMode is currently set to: $($DriverInstallMode)"
							switch ($DriverInstallMode) {
								"Single" {
									try {
										# Get driver full path and install each driver seperately
										$DriverINFs = Get-ChildItem -Path $ContentLocation -Recurse -Filter "*.inf" -ErrorAction Stop | Select-Object -Property FullName, Name
										if ($null -ne $DriverINFs) {
											foreach ($DriverINF in $DriverINFs) {
												# Install specific driver
												Write-MDMLogEntry -Value " - Attempting to install driver: $($DriverINF.FullName)"
												$ApplyDriverInvocation = Invoke-Executable -FilePath "dism.exe" -Arguments "/Image:$($Script:TSEnvironment.Value('OSDTargetSystemDrive'))\ /Add-Driver /Driver:`"$($DriverINF.FullName)`""
												# Validate driver injection
												if ($ApplyDriverInvocation -eq 0) { Write-MDMLogEntry -Value " - Successfully installed driver using dism.exe" }
												else { Write-MDMLogEntry -Value " - An error occurred while installing driver. Continuing with warning code: $($ApplyDriverInvocation). See DISM.log for more details" -Severity 2 }
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
									if ($ApplyDriverInvocation -eq 0) { Write-MDMLogEntry -Value " - Successfully installed drivers recursively in driver package content location using dism.exe" }
									else { Write-MDMLogEntry -Value " - An error occurred while installing drivers. Continuing with warning code: $($ApplyDriverInvocation). See DISM.log for more details" -Severity 2 }
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
					Write-MDMLogEntry -Value " - MDM package content downloaded successfully and located in: $($ContentLocation)"
					Set-MDMTaskSequenceVariable -TSVariable "OSDUpgradeStagedContent" -TsValue $ContentLocation
					Write-MDMLogEntry -Value " - Successfully completed MDM package staging process"
				}
				"SystemUpdate" {
					switch ($Filter) {
						"Driver" {
							# Apply drivers recursively from downloaded driver package location
							Write-MDMLogEntry -Value " - Driver package content downloaded successfully, attempting to apply drivers using pnputil.exe located in: $($ContentLocation)"
							$ApplyDriverInvocation = Invoke-Executable -FilePath "powershell.exe" -Arguments "pnputil /add-driver $(Join-Path -Path $ContentLocation -ChildPath '*.inf') /subdirs /install | Out-File -FilePath (Join-Path -Path $($LogsDirectory) -ChildPath 'Install-Drivers.txt') -Force"
							Write-MDMLogEntry -Value " - Successfully installed drivers"
						}
						"BIOS" {
							#ToDo
						}
					}
				}
				"PreCache" { Write-MDMLogEntry -Value " - MDM package content successfully downloaded and pre-cached to: $($ContentLocation)" }
			}#DeploymentType
			# Cleanup potential compressed driver package content
			switch -wildcard ($MDMPackageCompressedFile.Name) {
				"*.wim" {
					try {
						# Attempt to dismount compressed driver package content WIM file
						Write-MDMLogEntry -Value " - Attempting to dismount MDM package content WIM file: $($MDMPackageCompressedFile.Name) at $($MDMPackageMountLocation)"
						Dismount-WindowsImage -Path $MDMPackageMountLocation -Discard -ErrorAction Stop
						Write-MDMLogEntry -Value " - Successfully dismounted MDM package content WIM file"
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
	if ($DebugMode.IsPresent) {
		Write-MDMLogEntry -Value " - Saving matched MDM Package list into XML file which can be used as query source"
		$XmlOutput = ConvertTo-XmlQueryFile -MDMPackageList $MDMPackageList
		$XmlOutputFile = Join-Path -Path $LogsDirectory -ChildPath $XMLFileName
		Out-File -FilePath $XmlOutputFile -Encoding utf8 -Force -InputObject $XmlOutput
		Write-MDMLogEntry -Value " - Apply MDM Package script has successfully run in <debug mode>"
	}
	# Reset OSDDownloadContent.exe dependant variables before next task sequence step
	else { @("OSDDownloadDownloadPackages", "OSDDownloadDestinationLocationType", "OSDDownloadDestinationVariable", "OSDDownloadDestinationPath") | ForEach-Object { Set-MDMTaskSequenceVariable -TSVariable $_ } }
	Write-MDMLogEntry -Value "[InvokeMDMPackage]: Completed Apply MDM Package process"
	# Write final output of MDM Log entries
	Out-File -FilePath $LogFilePath -InputObject $script:LogEntries -Encoding default -NoClobber -Force
}
