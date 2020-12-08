<#
.SYNOPSIS
Download driver package (regular package) matching computer model, manufacturer and operating system.
.DESCRIPTION
This script will determine the model of the computer, manufacturer and operating system being deployed and then query
the specified AdminService endpoint for a list of Packages. It then sets the OSDDownloadDownloadPackages variable
to include the PackageID property of a package matching the computer model. If multiple packages are detect, it will select
most current one by the creation date of the packages.
.PARAMETER BareMetal
Set the script to operate in 'BareMetal' deployment type mode.
.PARAMETER DriverUpdate
Set the script to operate in 'DriverUpdate' deployment type mode.
.PARAMETER OSUpgrade
Set the script to operate in 'OSUpgrade' deployment type mode.
.PARAMETER PreCache
Set the script to operate in 'PreCache' deployment type mode.
.PARAMETER XMLPackage
Set the script to operate in 'XMLPackage' deployment type mode.
.PARAMETER DebugMode
Set the script to operate in 'DebugMode' deployment type mode.
.PARAMETER Endpoint
Specify the internal fully qualified domain name of the server hosting the AdminService, e.g. CM01.domain.local.
.PARAMETER XMLDeploymentType
Specify the deployment type mode for XML based driver package deployments, e.g. 'BareMetal', 'OSUpdate', 'DriverUpdate', 'PreCache'.
.PARAMETER UserName
Specify the service account user name used for authenticating against the AdminService endpoint.
.PARAMETER Password
Specify the service account password used for authenticating against the AdminService endpoint.
.PARAMETER Filter
Define a filter used when calling ConfigMgr WebService to only return objects matching the filter.
.PARAMETER TargetOSVersion
Define the value that will be used as the target operating system version e.g. '2004'.
.PARAMETER TargetOSArchitecture
Define the value that will be used as the target operating system architecture e.g. 'x64'.
.PARAMETER OperationalMode
Define the operational mode, either Production or Pilot, for when calling ConfigMgr WebService to only return objects matching the selected operational mode.
.PARAMETER UseDriverFallback
Specify if the script is to be used with a driver fallback package when a driver package for SystemSKU or computer model could not be detected.
.PARAMETER DriverInstallMode
Specify whether to install drivers using DISM.exe with recurse option or spawn a new process for each driver.
.PARAMETER PreCachePath
Specify a custom path for the PreCache directory, overriding the default CCMCache directory.
.PARAMETER Manufacturer
Override the automatically detected computer manufacturer when running in debug mode.
.PARAMETER ComputerModel
Override the automatically detected computer model when running in debug mode.
.PARAMETER SystemSKU
Override the automatically detected SystemSKU when running in debug mode.
.PARAMETER OSVersionFallback
Use this switch to check for drivers packages that matches earlier versions of Windows than what's specified as input for TargetOSVersion.
.EXAMPLE
# Detect, download and apply drivers during OS deployment with ConfigMgr:
.\Invoke-CMApplyDriverPackage.ps1 -BareMetal -Endpoint "CM01.domain.com" -TargetOSVersion 1909
# Detect, download and apply drivers during OS deployment with ConfigMgr and use a driver fallback package if no matching driver package can be found:
.\Invoke-CMApplyDriverPackage.ps1 -BareMetal -Endpoint "CM01.domain.com" -TargetOSVersion 1909 -UseDriverFallback
# Detect, download and apply drivers during OS deployment with ConfigMgr and check for driver packages that matches an earlier version than what's specified for TargetOSVersion:
.\Invoke-CMApplyDriverPackage.ps1 -BareMetal -Endpoint "CM01.domain.com" -TargetOSVersion 1909 -OSVersionFallback
# Detect and download drivers during OS upgrade with ConfigMgr:
.\Invoke-CMApplyDriverPackage.ps1 -OSUpgrade -Endpoint "CM01.domain.com" -TargetOSVersion 1909
# Detect, download and update a device with latest drivers for an running operating system using ConfigMgr:
.\Invoke-CMApplyDriverPackage.ps1 -DriverUpdate -Endpoint "CM01.domain.com"
# Detect and download (pre-caching content) during OS upgrade with ConfigMgr:
.\Invoke-CMApplyDriverPackage.ps1 -PreCache -Endpoint "CM01.domain.com" -TargetOSVersion 1909
# Detect and download (pre-caching content) to a custom path during OS upgrade with ConfigMgr:
.\Invoke-CMApplyDriverPackage.ps1 -PreCache -Endpoint "CM01.domain.com" -TargetOSVersion 1909 -PreCachePath "C:\Windows\Temp\DriverPackage"
# Run in a debug mode for testing purposes (to be used locally on the computer model):
.\Invoke-CMApplyDriverPackage.ps1 -DebugMode -Endpoint "CM01.domain.com" -UserName "svc@domain.com" -Password "svc-password" -TargetOSVersion 1909
# Run in a debug mode for testing purposes and overriding the automatically detected computer details (could be executed basically anywhere):
.\Invoke-CMApplyDriverPackage.ps1 -DebugMode -Endpoint "CM01.domain.com" -UserName "svc@domain.com" -Password "svc-password" -TargetOSVersion 1909 -Manufacturer "Dell" -ComputerModel "Precision 5520" -SystemSKU "07BF"
# Detect, download and apply drivers during OS deployment with ConfigMgr and use an XML package as the source of driver package details instead of the AdminService:
.\Invoke-CMApplyDriverPackage.ps1 -XMLPackage -TargetOSVersion "1909" -TargetOSArchitecture "x64" -XMLDeploymentType BareMetal
.NOTES
FileName:	Invoke-CMApplyDriverPackage.ps1
Author:	Nickolaj Andersen / Maurice Daly
Contact: 	@NickolajA / @MoDaly_IT
Created: 	2017-03-27
Updated: 	2020-09-16
Contributors: @CodyMathis123, @JamesMcwatty
Version history:
1.0.0 - (2017-03-27) - Script created
1.0.1 - (2017-04-18) - Updated script with better support for multiple vendor entries
1.0.2 - (2017-04-22) - Updated script with support for multiple operating systems driver packages, e.g. Windows 8.1 and Windows 10
1.0.3 - (2017-05-03) - Updated script with support for manufacturer specific Windows 10 versions for HP and Microsoft
1.0.4 - (2017-05-04) - Updated script to trim any white spaces trailing the computer model detection from WMI
1.0.5 - (2017-05-05) - Updated script to pull the model for Lenovo systems from the correct WMI class
1.0.6 - (2017-05-22) - Updated script to detect the proper package based upon OS Image version referenced in task sequence when multiple packages are detected
1.0.7 - (2017-05-26) - Updated script to filter OS when multiple model matches are found for different OS platforms
1.0.8 - (2017-06-26) - Updated script with improved computer name matching when filtering out packages returned from the web service
1.0.9 - (2017-08-25) - Updated script to read package description for Microsoft models in order to match the WMI value contained within
1.1.0 - (2017-08-29) - Updated script to only check for the OS build version instead of major, minor, build and revision for HP systems. $OSImageVersion will now only contain the most recent version if multiple OS images is referenced in the Task Sequence
1.1.1 - (2017-09-12) - Updated script to match the system SKU for Dell, Lenovo and HP models. Added architecture check for matching packages
1.1.2 - (2017-09-15) - Replaced computer model matching with SystemSKU. Added script with support for different exit codes
1.1.3 - (2017-09-18) - Added support for downloading package content instead of setting OSDDownloadDownloadPackages variable
1.1.4 - (2017-09-19) - Added support for installing driver package directly from this script instead of running a seperate DISM command line step
1.1.5 - (2017-10-12) - Added support for in full OS driver maintenance updates
1.1.6 - (2017-10-29) - Fixed an issue when detecting Microsoft manufacturer information
1.1.7 - (2017-10-29) - Changed the OSMaintenance parameter from a string to a switch object, make sure that your implementation of this is amended in any task sequence steps
1.1.8 - (2017-11-07) - Added support for driver fallback packages when the UseDriverFallback param is used
1.1.9 - (2017-12-12) - Added additional output for failure to detect system SKU value from WMI
1.2.0 - (2017-12-14) - Fixed an issue where the HP packages would not properly be matched against the OS image version returned by the web service
1.2.1 - (2018-01-03) - IMPORTANT - OSMaintenance switch has been replaced by the DeploymentType parameter. In order to support the default behavior (BareMetal), OSUpgrade and DriverUpdate operational
modes for the script, this change was required. Update your task sequence configuration before you use this update.
2.0.0 - (2018-01-10) - Updates include support for machines with blank system SKU values and the ability to run BIOS & driver updates in the FULL OS
2.0.1 - (2018-01-18) - Fixed a regex issue when attempting to fallback to computer model instead of SystemSKU
2.0.2 - (2018-01-24) - Re-constructed the logic for matching driver package to begin with computer model or SystemSKU (SystemSKU takes precedence before computer model) and improved the logging when matching for driver packages
2.0.3 - (2018-01-25) - Added a fix for multiple manufacturer package matches not working for Windows 7. Fixed an issue where SystemSKU was used and multiple driver packages matched. Added script line logging when the script cought an exception.
2.0.4 - (2018-01-26) - Changed from using a foreach loop to a for loop in reverse to remove driver packages that was matched by SystemSKU but does not match the computer model
2.0.5 - (2018-01-29) - Replaced Add-Content with Out-File for issue with file lock causing not all log entries to be written to the ApplyDriverPackage.log file
2.0.6 - (2018-02-21) - Updated to cater for the presence of underscores in Microsoft Surface models
2.0.7 - (2018-02-25) - Added support for a DebugMode switch for running script outside of a task sequence for driver package detection
2.0.8 - (2018-02-25) - Added a check to bail out the script if computer model and SystemSKU are null or an empty string
2.0.9 - (2018-05-07) - Removed exit code 34 event. DISM will now continue to process drivers if a single or multiple failures occur in order to proceed with the task sequence
2.1.0 - (2018-06-01) - IMPORTANT: From this version, ConfigMgr WebService 1.6 is required. Added a new parameter named OSImageTSVariableName that accepts input of a task sequence variable. This task sequence variable should contain the OS Image package ID of
the desired Operating System Image selected in an Apply Operating System step. This new functionality allows for using multiple Apply Operating System steps in a single task sequence. Added Panasonic for manufacturer detection.
Improved logic with fallback from SystemSKU to computer model. Script will now fall back to computer model if there was no match to the SystemSKU. This still requires that the SystemSKU contains a value and is not null or empty, otherwise
the logic will directly fall back to computer model. A new parameter named DriverInstallMode has been added to control how drivers are installed for BareMetal deployment. Valid inputs are Single or Recurse.
2.1.1 - (2018-08-28) - Code tweaks and changes for Windows build to version switch in the Driver Automation Tool. Improvements to the SystemSKU reverse section for HP models and multiple SystemSKU values from WMI
2.1.2 - (2018-08-29) - Added code to handle Windows 10 version specific matching and also support matching for the name only
2.1.3 - (2018-09-03) - Code tweak to Windows 10 version matching process
2.1.4 - (2018-09-18) - Added support to override the task sequence package ID retrieved from _SMSTSPackageID when the Apply Operating System step is in a child task sequence
2.1.5 - (2018-09-18) - Updated the computer model detection logic that replaces parts of the string from the PackageName property to retrieve the computer model only
2.1.6 - (2019-01-28) - Fixed an issue with the recurse injection of drivers for a single detected driver package that was using an unassigned variable
2.1.7 - (2019-02-13) - Added support for Windows 10 version 1809 in the Get-OSDetails function
2.1.8 - (2019-02-13) - Added trimming of manufacturer and models data gathering from WMI
2.1.9 - (2019-03-06) - Added support for non-terminating error when no matching driver packages where detected for OSUpgrade and DriverUpdate deployment types
2.2.0 - (2019-03-08) - Fixed an issue when attempting to run the script with -DebugMode switch that would cause it to break when it couldn't load the TS environment
2.2.1 - (2019-03-29) - New deployment type named 'PreCache' that allows the script to run in a pre-caching mode in a content pre-cache task sequence. When this deployment type is used, content will only be downloaded if it doesn't already
exist in the CCMCache. New parameter OperationalMode (defaults to Production) for better handling driver packages set for Pilot or Production deployment.
2.2.2 - (2019-05-14) - Improved the Surface model detection from WMI
2.2.3 - (2019-05-14) - Fixed an issue when multiple matching driver packages for a given model would only attempt to format the computer model name correctly for HP computers
2.2.4 - (2019-08-09) - Fixed an issue on OperationalMode Production to filter out pilot and retired packages
2.2.5 - (2019-12-02) - Added support for Windows 10 1903, 1909 and additional matching for Microsoft Surface devices (DAT 6.4.0 or neweer)
2.2.6 - (2020-02-06) - Fixed an issue where the single driver injection mode for BareMetal deployments would fail if there was a space in the driver inf name
2.2.7 - (2020-02-10) - Added a new parameter named TargetOSVersion. Use this parameter when DeploymentType is OSUpgrade and you don't want to rely on the OS version detected from the imported Operating System Upgrade Package or Operating System Image objects.
This parameter should mainly be used as an override and was implemented due to drivers for Windows 10 1903 were incorrectly detected when deploying or upgrading to Windows 10 1909 using imported source files, not for a
reference image for Windows 10 1909 as the Enablement Package would have flipped the build change to 18363 in such an image.
3.0.0 - (2020-03-14) - A complete re-written version of the script. Includes a much improved logging functionality. Script is now divided into phases, which are represented in the ApplyDriverPackage.log that will provide a better troubleshooting experience.
Added support for AZW and Fujitsu computer manufacturer by request from the community. Extended DebugMode to allow for overriding computer details, which allows the script to be tested against any model and it doesn't require to be tested
directly on the model itself.
3.0.1 - (2020-03-25) - Added TargetOSVersion parameter to be allowed to used in DebugMode.
- Fixed an issue where DebugMode would not be allowed to run on virtual machines. Fixed an issue where ComputerDetectionMethod script variable would be set to ComputerModel from
SystemSKU in case it couldn't match on the first driver package, leading to HP driver packages would always fail since they barely never match on the ComputerModel (they include 'Base Model', 'Notebook PC' etc.)
3.0.2 - (2020-03-29) - Fixed a spelling mistake in the Manufacturer parameter.
3.0.3 - (2020-03-31) - Small update to the Filter parameter's default value, it's now 'Drivers' instead of 'Driver'. Also added '64 bits' and '32 bits' to the translation function for the OS architecture of the current running task sequence.
3.0.4 - (2020-04-09) - Changed the translation function for the OS architecture of the current running task sequence into using wildcard support instead of adding language specified values
3.0.5 - (2020-04-30) - Added 7-Zip self extracting exe support for compressed driver packages
4.0.0 - (2020-06-29) - IMPORTANT: From this version and onwards, usage of the ConfigMgr WebService has been deprecated. This version will only work with the built-in AdminService in ConfigMgr.
Removed the DeploymentType parameter and replaced each deployment type with it's own switch parameter, e.g. -BareMetal, -DriverUpdate etc. Additional new parameters have been added, including the requirements of pre-defined Task Sequence variables
that the script requires. For more information, please refer to the embedded examples of how to use this script or refer to the official documentation at https://www.msendpointmgr.com/modern-driver-management.
4.0.1 - (2020-07-24) - Fixed an issue where an improper variable name was used instead of $DriverPackageCompressedFile
4.0.2 - (2020-08-07) - Fixed an issue where the Confirm-SystemSKU function would cause the script to crash if the SystemSKU data was improperly conformed, e.g. with spaces as a delimiter or with duplicate entries
4.0.3 - (2020-08-28) - Fixed an issue where the script would fail in case the driver package was missing SystemSKU values
4.0.4 - (2020-09-10) - IMPORTANT: This update addresses a change in Driver Automation Tool version 6.4.9 that comes with a change in naming HP driver packages such as 'Drivers - HP EliteBook x360 1030 G2 Base Model - Windows 10 1909 x64' instead of Hewlett-Packard in the name.
Before changing to version 4.0.4 of this script, ensure Driver Automation Tool have been executed and all HP driver packages now reflect these changes.
- Added support for decompressing WIM driver packages.
4.0.5 - (2020-09-16) - Fixed an issue for driver package compressed WIM support where it could not mount the file as the location was not empty, thanks to @SuneThomsenDK for reporting this.
4.0.6 - (2020-10-11) - Improved the AdminServiceEndpointType detection logic to mainly use the 'InInternet' property from ClientInfo WMI class together with if any detected type of active MP candidate was detected.
4.0.7 - (2020-10-27) - Updated with support for Windows 10 version 2009.
4.0.8 - (2020-11-26) - Fixed an issue with WIM file formatted drivers not extracting correctly
4.0.8.1 - (2020-12-08) - Alternative version with some code shuffling and rewrite of functions retaining expected output
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
	[parameter(HelpMessage = "Set the script to operate in 'DebugMode' deployment type mode.")]
	[switch]$DebugMode,
	[parameter(HelpMessage = "Specify the internal fully qualified domain name of the server hosting the AdminService, e.g. CM01.domain.local.")]
	[ValidateNotNullOrEmpty()]
	[string]$Endpoint,
	[parameter(HelpMessage = "Specify the deployment type mode for driver package deployments, e.g. 'BareMetal', 'OSUpdate', 'DriverUpdate', 'PreCache'.")]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("BareMetal", "OSUpdate", "DriverUpdate", "PreCache")]
	[string]$DeploymentType = "BareMetal",
	[parameter(ParameterSetName = "Debug", HelpMessage = "Specify the service account user name used for authenticating against the AdminService endpoint.")]
	[string]$UserName = "",
	[parameter(ParameterSetName = "Debug", HelpMessage = "Specify the service account password used for authenticating against the AdminService endpoint.")]
	[string]$Password,
	[parameter(HelpMessage = "Define a filter used when calling the AdminService to only return objects matching the filter.")]
	[ValidateNotNullOrEmpty()]
	[string]$Filter = "Drivers",
	[parameter(HelpMessage = "Define the value that will be used as the target operating system version e.g. '2004'.")]
	[ValidateNotNullOrEmpty()]
	[ValidateScript( { $OsBuildVersions.ContainsValue($_) })]
	[string]$TargetOSVersion,
	[parameter(HelpMessage = "Define the value that will be used as the target operating system architecture e.g. 'x64'.")]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("x64", "x86")]
	[string]$OSArchitecture = "x64",
	[parameter(HelpMessage = "Define the operational mode, either Production or Pilot, for when calling ConfigMgr WebService to only return objects matching the selected operational mode.")]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("Production", "Pilot")]
	[string]$OperationalMode = "Production",
	[parameter(HelpMessage = "Specify if the script is to be used with a driver fallback package when a driver package for SystemSKU or computer model could not be detected.")]
	[switch]$UseDriverFallback,
	[parameter(HelpMessage = "Specify whether to install drivers using DISM.exe with recurse option or spawn a new process for each driver.")]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("Single", "Recurse")]
	[string]$DriverInstallMode = "Recurse",
	[parameter(HelpMessage = "Specify a custom path for the PreCache directory, overriding the default CCMCache directory.")]
	[ValidateNotNullOrEmpty()]
	[string]$PreCachePath,
	[parameter(HelpMessage = "Override the automatically detected computer manufacturer.")]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("Hewlett-Packard", "HP", "Dell", "Lenovo", "Microsoft", "Fujitsu", "Panasonic", "Viglen", "AZW")]
	[string]$Manufacturer,
	[parameter(HelpMessage = "Override the automatically detected computer model.")]
	[ValidateNotNullOrEmpty()]
	[string]$ComputerModel,
	[parameter(HelpMessage = "Override the automatically detected SystemSKU.")]
	[ValidateNotNullOrEmpty()]
	[string]$SystemSKU,
	[parameter(HelpMessage = "Use this switch to check for drivers packages that matches earlier versions of Windows than what's specified as input for TargetOSVersion.")]
	[switch]$OSVersionFallback,
	[parameter(HelpMessage = "Name of the log file for script output.")]
	[ValidateNotNullOrEmpty()]
	[string]$LogFileName = "ApplyDriverPackage.log"
)

Process {
	Write-CMLogEntry -Value "[ApplyDriverPackage]: Apply Driver Package script version $($ScriptVersion) initiated"
	Write-CMLogEntry -Value " - Apply driver package process initiated in $($DeploymentType) deployment mode"
	Write-CMLogEntry -Value " - Apply driver package in $($OperationalMode) mode"
	# Set script error preference variable
	$ErrorActionPreference = "Stop"
	# Construct array list for matched drivers packages
	$script:DriverPackageList = New-Object -TypeName "System.Collections.ArrayList"
	# Set initial values that control whether some functions should be executed or not
	$script:SkipFallbackDriverPackageValidation = $false
	try {
		Write-CMLogEntry -Value "[PrerequisiteChecker]: Starting environment prerequisite checker"
		# Determine computer OS version, Manufacturer, Model, SystemSKU and FallbackSKU
		$ComputerData = Get-ComputerData
		# Determine the computer detection method to be used for matching against driver packages
		$ComputerDetectionMethod = $ComputerData.DetectionMethod
		Write-CMLogEntry -Value "[PrerequisiteChecker]: Completed environment prerequisite checker"
		switch ($PSCmdLet.ParameterSetName) {
			"XMLPackage" {
				$Script:PackageSource = "XML Package Logic file"
				# Define the path for the pre-downloaded XML Package Logic file called DriverPackages.xml
				$script:XMLPackageLogicFile = (Join-Path -Path $Script:TSEnvironment.Value("MDMXMLPackage01") -ChildPath "DriverPackages.xml")
				if (-not(Test-Path -Path $script:XMLPackageLogicFile)) {
					Write-CMLogEntry -Value " - Failed to locate required 'DriverPackages.xml' logic file for XMLPackage deployment type, ensure it has been pre-downloaded in a Download Package Content step before running this script" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
			}
			default {
				$Script:PackageSource = "AdminService"
				Write-CMLogEntry -Value "[AdminService]: Starting AdminService endpoint phase"
				# Detect AdminService endpoint
				Get-AdminServiceEndpoint
				# Determine if required values to connect to AdminService are provided
				Test-AdminServiceData
				# Construct PSCredential object for AdminService authentication, this is required for both endpoint types
				Get-AuthCredential
				# Attempt to retrieve an authentication token for external AdminService endpoint connectivity
				# This will only execute when the endpoint type has been detected as External, which means that authentication is needed against the Cloud Management Gateway
				if ($Script:AdminServiceEndpointType -like "External") { Get-AuthToken }
				Write-CMLogEntry -Value "[AdminService]: Completed AdminService endpoint phase"
			}
		}#switch
		Write-CMLogEntry -Value "[DriverPackage]: Starting driver package retrieval using method: $($Script:PackageSource)"
		# Retrieve available driver packages from web service
		$DriverPackages = Get-DriverPackages
		Write-CMLogEntry -Value "[DriverPackage]: Starting driver package matching phase"
		# Match detected driver packages from web service call with computer details and OS image details gathered previously
		Confirm-DriverPackage -ComputerData $ComputerData -OSImageData $ComputerData -DriverPackage $DriverPackages
		Write-CMLogEntry -Value "[DriverPackage]: Completed driver package matching phase"
		# Validate that at least one driver package was matched against computer data
		# Check if multiple driver packages were detected and ensure the most recent one by sorting after the DateCreated property from original web service call
		Confirm-DriverPackageList
		# Handle UseDriverFallback parameter if it was passed on the command line and attempt to detect if there's any available fallback packages
		# This function will only run in the case that the parameter UseDriverFallback was specified and if the $script:DriverPackageList is empty at the point of execution
		if ($PSBoundParameters["UseDriverFallback"]) {
			Write-CMLogEntry -Value "[DriverPackageFallback]: Starting fallback driver package detection phase"
			# Match detected fallback driver packages from web service call with computer details and OS image details
			Confirm-FallbackDriverPackage -ComputerData $ComputerData -WebService $WebService
			Write-CMLogEntry -Value "[DriverPackageFallback]: Completed fallback driver package detection phase"
			Write-CMLogEntry -Value "[DriverPackageFallbackValidation]: Starting fallback driver package validation phase"
			# Validate that at least one fallback driver package was matched against computer data
			Confirm-FallbackDriverPackageList
			Write-CMLogEntry -Value "[DriverPackageFallbackValidation]: Completed fallback driver package validation phase"
		}
		# At this point, the code below here is not allowed to be executed in debug mode, as it requires access to the Microsoft.SMS.TSEnvironment COM object
		if ($PSCmdLet.ParameterSetName -notlike "Debug") {
			Write-CMLogEntry -Value "[DriverPackageDownload]: Starting driver package download phase"
			# Attempt to download the matched driver package content files from distribution point
			$DriverPackageContentLocation = Invoke-DownloadDriverPackageContent
			Write-CMLogEntry -Value "[DriverPackageDownload]: Completed driver package download phase"
			# Depending on deployment type, take action accordingly when applying the driver package files
			Install-DriverPackageContent -ContentLocation $DriverPackageContentLocation
			Write-CMLogEntry -Value "[DriverPackageInstall]: Completed driver package install phase"
		}
		else {
			Write-CMLogEntry -Value " - Script has successfully completed debug mode"
		}
	}
	catch [System.Exception] {
		Write-CMLogEntry -Value "[ApplyDriverPackage]: Apply Driver Package process failed, please refer to previous error or warning messages" -Severity 3
		# Main try-catch block was triggered, this should cause the script to fail with exit code 1
		exit 1
	}
}#process

Begin {
	[version]$ScriptVersion = "4.0.8.1"
	$LogsDirectory = Join-Path -Path $env:SystemRoot -ChildPath "Temp"
	try { 
		$Script:TSEnvironment = New-Object -ComObject "Microsoft.SMS.TSEnvironment" -ErrorAction Stop
		$LogsDirectory = $Script:TSEnvironment.Value("_SMSTSLogPath")
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
	function New-TerminatingErrorRecord {
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
			[ValidateNotNullOrEmpty()]
			[string]$TargetObject = ([string]::Empty),
			[parameter(HelpMessage = "Throws Error when set to true.")]
			[ValidateNotNullOrEmpty()]
			[switch]$ThrowError
		)
		# Construct new error record to be returned from function based on parameter inputs
		$SystemException = New-Object -TypeName $Exception -ArgumentList $Message
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
	function Invoke-CMDownloadContent {
		param (
			[parameter(Mandatory, ParameterSetName = "NoPath", HelpMessage = "Specify a PackageID that will be downloaded.")]
			[Parameter(ParameterSetName = "CustomPath")]
			[ValidateNotNullOrEmpty()]
			[ValidatePattern("^[A-Z0-9]{3}[A-F0-9]{5}$")]
			[string]$PackageID,
			[parameter(Mandatory, ParameterSetName = "NoPath", HelpMessage = "Specify the download location type.")]
			[Parameter(ParameterSetName = "CustomPath")]
			[ValidateNotNullOrEmpty()]
			[ValidateSet("Custom", "TSCache", "CCMCache")]
			[string]$DestinationLocationType,
			[parameter(Mandatory, ParameterSetName = "NoPath", HelpMessage = "Save the download location to the specified variable name.")]
			[Parameter(ParameterSetName = "CustomPath")]
			[ValidateNotNullOrEmpty()]
			[string]$DestinationVariableName,
			[parameter(Mandatory, ParameterSetName = "CustomPath", HelpMessage = "When location type is specified as Custom, specify the custom path.")]
			[ValidateNotNullOrEmpty()]
			[string]$CustomLocationPath
		)
		# Set OSDDownloadDownloadPackages
		Write-CMLogEntry -Value " - Setting task sequence variable OSDDownloadDownloadPackages to: $($PackageID)"
		$Script:TSEnvironment.Value("OSDDownloadDownloadPackages") = "$($PackageID)"
		# Set OSDDownloadDestinationLocationType
		Write-CMLogEntry -Value " - Setting task sequence variable OSDDownloadDestinationLocationType to: $($DestinationLocationType)"
		$Script:TSEnvironment.Value("OSDDownloadDestinationLocationType") = "$($DestinationLocationType)"
		# Set OSDDownloadDestinationVariable
		Write-CMLogEntry -Value " - Setting task sequence variable OSDDownloadDestinationVariable to: $($DestinationVariableName)"
		$Script:TSEnvironment.Value("OSDDownloadDestinationVariable") = "$($DestinationVariableName)"
		# Set OSDDownloadDestinationPath
		if ($DestinationLocationType -like "Custom") {
			Write-CMLogEntry -Value " - Setting task sequence variable OSDDownloadDestinationPath to: $($CustomLocationPath)"
			$Script:TSEnvironment.Value("OSDDownloadDestinationPath") = "$($CustomLocationPath)"
		}
		# Set SMSTSDownloadRetryCount to 1000 to overcome potential BranchCache issue that will cause 'SendWinHttpRequest failed. 80072efe'
		$Script:TSEnvironment.Value("SMSTSDownloadRetryCount") = 1000
		# Invoke download of package content
		try {
			if ($Script:TSEnvironment.Value("_SMSTSInWinPE") -eq $false) {
				Write-CMLogEntry -Value " - Starting package content download process (FullOS), this might take some time"
				$ReturnCode = Invoke-Executable -FilePath (Join-Path -Path $env:windir -ChildPath "CCM\OSDDownloadContent.exe")
			}
			else {
				Write-CMLogEntry -Value " - Starting package content download process (WinPE), this might take some time"
				$ReturnCode = Invoke-Executable -FilePath "OSDDownloadContent.exe"
			}
			# Reset SMSTSDownloadRetryCount to 5 after attempted download
			$Script:TSEnvironment.Value("SMSTSDownloadRetryCount") = 5
			# Match on return code
			if ($ReturnCode -eq 0) { Write-CMLogEntry -Value " - Successfully downloaded package content with PackageID: $($PackageID)" }
			else {
				Write-CMLogEntry -Value " - Failed to download package content with PackageID '$($PackageID)'. Return code was: $($ReturnCode)" -Severity 3
				# Throw terminating error
				New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
			}
		}
		catch [System.Exception] {
			Write-CMLogEntry -Value " - An error occurred while attempting to download package content. Error message: $($_.Exception.Message)" -Severity 3
			# Throw terminating error
			New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
		}
		return $ReturnCode
	}
	function Invoke-CMResetDownloadContentVariables {
		param(
			[string[]]$DownloadContentVariables = @("OSDDownloadDownloadPackages", "OSDDownloadDestinationLocationType", "OSDDownloadDestinationVariable", "OSDDownloadDestinationPath")
		)
		# blank OSD DownloadContentVariables
		foreach ($DownloadContentVariable in $DownloadContentVariables) {
			$script:LogLines.add($(Write-CMLogEntry -Value " - Setting task sequence variable $($DownloadContentVariable) to a blank value"))
			$Script:TSEnvironment.Value($DownloadContentVariable) = [System.String]::Empty
		}
	}	
	function ConvertTo-ObfuscatedString {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the string to be obfuscated for log output.")]
			[ValidateNotNullOrEmpty()]
			[string]$InputObject
		)
		# Convert input object to a character array
		$StringArray = $InputObject.ToCharArray()
		# Loop through each character obfuscate every second item, with exceptions of the @ and period character if present
		for ($i = 1; $i -lt $StringArray.Count; $i++) { $StringArray[$i] = $StringArray[$i] -replace "[^@\.]", "*"; $i++ }
		# Join character array and return value
		return -join @($StringArray)
	}
	function Test-AdminServiceData {
		# Validate correct value have been either set as a TS environment variable or passed as parameter input for service account user name used to authenticate against the AdminService
		if ([string]::IsNullOrEmpty($Script:UserName)) {
			switch ($PSCmdLet.ParameterSetName) {
				"Debug" {
					Write-CMLogEntry -Value " - Required service account user name could not be determined from parameter input" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
				default {
					# Attempt to read TSEnvironment variable MDMUserName
					$Script:UserName = $Script:TSEnvironment.Value("MDMUserName")
					if (-not([string]::IsNullOrEmpty($Script:UserName))) {
						# Obfuscate user name
						$ObfuscatedUserName = ConvertTo-ObfuscatedString -InputObject $Script:UserName
						Write-CMLogEntry -Value " - Successfully read service account user name from TS environment variable 'MDMUserName': $($ObfuscatedUserName)"
					}
					else {
						Write-CMLogEntry -Value " - Required service account user name could not be determined from TS environment variable" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
				}
			}
		}
		else {
			# Obfuscate user name
			$ObfuscatedUserName = ConvertTo-ObfuscatedString -InputObject $Script:UserName
			Write-CMLogEntry -Value " - Successfully read service account user name from parameter input: $($ObfuscatedUserName)"
		}
		# Validate correct value have been either set as a TS environment variable or passed as parameter input for service account password used to authenticate against the AdminService
		if ([string]::IsNullOrEmpty($Script:Password)) {
			switch ($Script:PSCmdLet.ParameterSetName) {
				"Debug" {
					Write-CMLogEntry -Value " - Required service account password could not be determined from parameter input" -Severity 3
				}
				default {
					# Attempt to read TSEnvironment variable MDMPassword
					$Script:Password = $Script:TSEnvironment.Value("MDMPassword")
					if (-not([string]::IsNullOrEmpty($Script:Password))) {
						Write-CMLogEntry -Value " - Successfully read service account password from TS environment variable 'MDMPassword': ********"
					}
					else {
						Write-CMLogEntry -Value " - Required service account password could not be determined from TS environment variable" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
				}
			}
		}
		else { Write-CMLogEntry -Value " - Successfully read service account password from parameter input: ********" }
		# Validate that if determined AdminService endpoint type is external, that additional required TS environment variables are available
		if ($Script:AdminServiceEndpointType -like "External") {
			if ($Script:PSCmdLet.ParameterSetName -notlike "Debug") {
				# Attempt to read TSEnvironment variable MDMExternalEndpoint
				$Script:ExternalEndpoint = $Script:TSEnvironment.Value("MDMExternalEndpoint")
				if (-not([string]::IsNullOrEmpty($Script:ExternalEndpoint))) {
					Write-CMLogEntry -Value " - Successfully read external endpoint address for AdminService through CMG from TS environment variable 'MDMExternalEndpoint': $($Script:ExternalEndpoint)"
				}
				else {
					Write-CMLogEntry -Value " - Required external endpoint address for AdminService through CMG could not be determined from TS environment variable" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
				# Attempt to read TSEnvironment variable MDMClientID
				$Script:ClientID = $Script:TSEnvironment.Value("MDMClientID")
				if (-not([string]::IsNullOrEmpty($Script:ClientID))) {
					Write-CMLogEntry -Value " - Successfully read client identification for AdminService through CMG from TS environment variable 'MDMClientID': $($Script:ClientID)"
				}
				else {
					Write-CMLogEntry -Value " - Required client identification for AdminService through CMG could not be determined from TS environment variable" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
				# Attempt to read TSEnvironment variable MDMTenantName
				$Script:TenantName = $Script:TSEnvironment.Value("MDMTenantName")
				if (-not([string]::IsNullOrEmpty($Script:TenantName))) {
					Write-CMLogEntry -Value " - Successfully read client identification for AdminService through CMG from TS environment variable 'MDMTenantName': $($Script:TenantName)"
				}
				else {
					Write-CMLogEntry -Value " - Required client identification for AdminService through CMG could not be determined from TS environment variable" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
			}
		}
	}
	function Get-AdminServiceEndpoint {
		switch ($Script:PSCmdlet.ParameterSetName) {
			"BareMetal" {
				$SMSInWinPE = $Script:TSEnvironment.Value("_SMSTSInWinPE")
				if ($SMSInWinPE -eq $true) {
					Write-CMLogEntry -Value " - Detected that script was running within a task sequence in WinPE phase, automatically configuring AdminService endpoint type"
					$Script:AdminServiceEndpointType = "Internal"
				}
				else {
					Write-CMLogEntry -Value " - Detected that script was not running in WinPE of a bare metal deployment type, this is not a supported scenario" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
			}
			"Debug" {
				$Script:AdminServiceEndpointType = "Internal"
			}
			default {
				Write-CMLogEntry -Value " - Attempting to determine AdminService endpoint type based on current active Management Point candidates and from ClientInfo class"
				# Determine active MP candidates and if
				$ActiveMPCandidates = Get-WmiObject -Namespace "root\ccm\LocationServices" -Class "SMS_ActiveMPCandidate"
				$ActiveMPInternalCandidatesCount = ($ActiveMPCandidates | Where-Object { $PSItem.Type -like "Assigned" } | Measure-Object).Count
				$ActiveMPExternalCandidatesCount = ($ActiveMPCandidates | Where-Object { $PSItem.Type -like "Internet" } | Measure-Object).Count
				# Determine if ConfigMgr client has detected if the computer is currently on internet or intranet
				$CMClientInfo = Get-WmiObject -Namespace "root\ccm" -Class "ClientInfo"
				switch ($CMClientInfo.InInternet) {
					$true {
						if ($ActiveMPExternalCandidatesCount -ge 1) { $Script:AdminServiceEndpointType = "External" }
						else {
							Write-CMLogEntry -Value " - Detected as an Internet client but unable to determine External AdminService endpoint, bailing out" -Severity 3
							# Throw terminating error
							New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
						}
					}
					$false {
						if ($ActiveMPInternalCandidatesCount -ge 1) { $Script:AdminServiceEndpointType = "Internal" }
						else {
							Write-CMLogEntry -Value " - Detected as an Intranet client but unable to determine Internal AdminService endpoint, bailing out" -Severity 3
							# Throw terminating error
							New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
						}
					}
				}
			}
		}#switch
		Write-CMLogEntry -Value " - Determined AdminService endpoint type as: $($script:AdminServiceEndpointType)"
		switch ($Script:AdminServiceEndpointType) {
			"Internal" { $Script:AdminServiceURL = = "https://{0}/AdminService/wmi" -f $Endpoint }
			"External" { $Script:AdminServiceURL = = "{0}/wmi" -f $ExternalEndpoint }
		}
		Write-CMLogEntry -Value " - Setting 'AdminServiceURL' variable to: $($Script:AdminServiceURL)"
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
				# Install NuGet package provider
				$PackageProvider = Install-PackageProvider -Name "NuGet" -Force -Verbose:$false
				# Install PSIntuneAuth module
				Install-Module -Name $ModuleName -Scope AllUsers -Force -ErrorAction Stop -Confirm:$false -Verbose:$false
				Write-CMLogEntry -Value " - Successfully installed $($ModuleName) module"
			}
			catch [System.Exception] {
				Write-CMLogEntry -Value " - An error occurred while attempting to install $($ModuleName) module. Error message: $($_.Exception.Message)" -Severity 3
				# Throw terminating error
				New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
			}
		}
	}
	function Get-AuthToken {
		try {
			# Attempt to install PSIntuneAuth module, if already installed ensure the latest version is being used
			Install-AuthModule
			# Retrieve authentication token
			Write-CMLogEntry -Value " - Attempting to retrieve authentication token using native client with ID: $($ClientID)"
			$Script:AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName -ClientID $ClientID -Credential $Credential -Resource "https://ConfigMgrService" -RedirectUri "https://login.microsoftonline.com/common/oauth2/nativeclient" -ErrorAction Stop
			Write-CMLogEntry -Value " - Successfully retrieved authentication token"
		}
		catch [System.Exception] {
			Write-CMLogEntry -Value " - Failed to retrieve authentication token. Error message: $($PSItem.Exception.Message)" -Severity 3
			# Throw terminating error
			New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
		}
	}
	function Get-AuthCredential {
		# Construct PSCredential object for authentication
		$EncryptedPassword = ConvertTo-SecureString -String $Script:Password -AsPlainText -Force
		$Script:Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @($Script:UserName, $EncryptedPassword)
	}
	function Get-AdminServiceItem {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the resource for the AdminService API call, e.g. '/SMS_Package'.")]
			[ValidateNotNullOrEmpty()]
			[string]$Resource
		)
		# Construct array object to hold return value
		$PackageArray = New-Object -TypeName System.Collections.ArrayList
		switch ($Script:AdminServiceEndpointType) {
			"External" {
				try {
					$AdminServiceUri = $AdminServiceURL + $Resource
					Write-CMLogEntry -Value " - Calling AdminService endpoint with URI: $($AdminServiceUri)"
					$AdminServiceResponse = Invoke-RestMethod -Method Get -Uri $AdminServiceUri -Headers $AuthToken -ErrorAction Stop
				}
				catch [System.Exception] {
					Write-CMLogEntry -Value " - Failed to retrieve available package items from AdminService endpoint. Error message: $($PSItem.Exception.Message)" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
			}
			"Internal" {
				$AdminServiceUri = $AdminServiceURL + $Resource
				Write-CMLogEntry -Value " - Calling AdminService endpoint with URI: $($AdminServiceUri)"
				try {
					# Call AdminService endpoint to retrieve package data
					$AdminServiceResponse = Invoke-RestMethod -Method Get -Uri $AdminServiceUri -Credential $Credential -ErrorAction Stop
				}
				catch [System.Security.Authentication.AuthenticationException] {
					Write-CMLogEntry -Value " - The remote AdminService endpoint certificate is invalid according to the validation procedure. Error message: $($PSItem.Exception.Message)" -Severity 2
					Write-CMLogEntry -Value " - Will attempt to set the current session to ignore self-signed certificates and retry AdminService endpoint connection" -Severity 2
					# Attempt to ignore self-signed certificate binding for AdminService
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
					catch [System.Exception] {
						Write-CMLogEntry -Value " - Failed to retrieve available package items from AdminService endpoint. Error message: $($PSItem.Exception.Message)" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
				}
				catch {
					Write-CMLogEntry -Value " - Failed to retrieve available package items from AdminService endpoint. Error message: $($PSItem.Exception.Message)" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
			}
		}
		# Add returned driver package objects to array list
		if ($null -ne $AdminServiceResponse.value) {
			foreach ($Package in $AdminServiceResponse.value) {
				$PackageArray.Add($Package) | Out-Null
			}
		}
		# Handle return value
		return $PackageArray
	}
	function Get-OSBuild {
		[System.Version]$OSBuild = (Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Version)
		$OSVersion = $script:OsBuildVersions[$($OSBuild.Build).ToString()]
		if ([string]::IsNullOrEmpty($OSVersion)) {
			Write-CMLogEntry -Value " - Unable to translate OS Build $($OSBuild.ToString()) to shorthand version " -Severity 3
			Write-CMLogEntry -Value " - Unsupported OS version detected, please reach out to the developers of this script" -Severity 3
			New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
		}
		# Handle return value from function
		return $OSVersion
	}
	function Get-OSArchitecture {
		$InputObject = (Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty OSArchitecture)
		$OSArchitecture = switch -Wildcard ($InputObject) {
			"9" { "x64" }
			"0" { "x86" }
			"64*" { "x64" }
			"32*" { "x86" }
			default {
				Write-CMLogEntry -Value " - Unable to translate OS architecture using input object: $($InputObject)" -Severity 3
				New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
			}
		}
		# Handle return value from function
		return $OSArchitecture
	}
	function Get-DriverPackages {
		try {
			# Retrieve driver packages but filter out matches depending on script operational mode
			switch ($OperationalMode) {
				"Production" {
					if ($Script:PSCmdlet.ParameterSetName -like "XMLPackage") {
						Write-CMLogEntry -Value " - Reading XML content logic file driver package entries"
						$Packages = (([xml]$(Get-Content -Path $script:XMLPackageLogicFile -Raw)).ArrayOfCMPackage).CMPackage | Where-Object { $_.Name -notmatch "Pilot" -and $_.Name -notmatch "Legacy" -and $_.Name -match $Filter }
					}
					else {
						Write-CMLogEntry -Value " - Querying AdminService for driver package instances"
						$Packages = Get-AdminServiceItem -Resource "/SMS_Package?`$filter=contains(Name,'$($Filter)')" | Where-Object { $_.Name -notmatch "Pilot" -and $_.Name -notmatch "Retired" }
					}
				}
				"Pilot" {
					if ($Script:PSCmdlet.ParameterSetName -like "XMLPackage") {
						Write-CMLogEntry -Value " - Reading XML content logic file driver package entries"
						$Packages = (([xml]$(Get-Content -Path $script:XMLPackageLogicFile -Raw)).ArrayOfCMPackage).CMPackage | Where-Object { $_.Name -match "Pilot" -and $_.Name -match $Filter }
					}
					else {
						Write-CMLogEntry -Value " - Querying AdminService for driver package instances"
						$Packages = Get-AdminServiceItem -Resource "/SMS_Package?`$filter=contains(Name,'$($Filter)')" | Where-Object { $_.Name -match "Pilot" }
					}
				}
			}
			# Handle return value
			if ($null -ne $Packages) {
				Write-CMLogEntry -Value " - Retrieved a total of '$(($Packages | Measure-Object).Count)' driver packages from $($Script:PackageSource) matching operational mode: $($OperationalMode)"
				return $Packages
			}
			else {
				Write-CMLogEntry -Value " - Retrieved a total of '0' driver packages from $($Script:PackageSource) matching operational mode: $($OperationalMode)" -Severity 3
				# Throw terminating error
				New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
			}
		}
		catch [System.Exception] {
			Write-CMLogEntry -Value " - An error occurred while calling $($Script:PackageSource) for a list of available driver packages. Error message: $($_.Exception.Message)" -Severity 3
			# Throw terminating error
			New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
		}
	}
	function Get-ComputerData {
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
			default { if (-not $DebugMode.IsPresent) { New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError } }
		}
		#if not explicitly defined via param then set computer data value(s)
		if (-not ($PSBoundParameters.ContainsKey('ComputerModel'))) {
			$ComputerModel = (Get-CimInstance -Namespace $NameSpace -ClassName $ModelClass | Select-Object -ExpandProperty $ModelProp).Trim()
		}
		$DetectionMethod = "ComputerModel"
		if (-not ($PSBoundParameters.ContainsKey('SystemSKU'))) {
			$SystemSKU = (Get-CimInstance -Namespace $NameSpace -ClassName $SkuClass | Select-Object -ExpandProperty $SkuProp).Trim()
			if ($Manufacturer -eq "Lenovo") { $SystemSKU = $SystemSKU.Substring(0, 4) }
			$DetectionMethod = "SystemSKU"
		}
		if (-not ($PSBoundParameters.ContainsKey('OSVersion'))) { $OSVersion = Get-OSBuild }
		if (-not ($PSBoundParameters.ContainsKey('OSArchitecture'))) { $OSArchitecture = Get-OSArchitecture }
		#if (-not ($PSBoundParameters.ContainsKey('OSVersionFallback'))) { }
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
			OSName          = "Windows 10"
			OSVersion       = $OSVersion
			Architecture    = $OSArchitecture
			Manufacturer    = $Manufacturer
			Model           = $ComputerModel
			SystemSKU       = $SystemSKU
			FallbackSKU     = $FallBackSKU
			DetectionMethod = $DetectionMethod
		}
		# Handle return value from function
		return $ComputerDetails
	}
	function Confirm-DriverPackage {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the computer details object from Get-ComputerDetails function.")]
			[ValidateNotNullOrEmpty()]
			[PSCustomObject]$ComputerData,
			[parameter(Mandatory, HelpMessage = "Specify the OS Image details object from Get-OSImageDetails function.")]
			[ValidateNotNullOrEmpty()]
			[PSCustomObject]$OSImageData,
			[parameter(Mandatory, HelpMessage = "Specify the driver package object to be validated.")]
			[ValidateNotNullOrEmpty()]
			[System.Object[]]$DriverPackage,
			[parameter(HelpMessage = "Set to True to check for drivers packages that matches earlier versions of Windows than what's detected from web service call.")]
			[ValidateNotNullOrEmpty()]
			[bool]$OSVersionFallback = $false
		)
		# Sort all driver package objects by package name property
		$DriverPackages = $DriverPackage | Sort-Object -Property PackageName
		$DriverPackagesCount = ($DriverPackages | Measure-Object).Count
		Write-CMLogEntry -Value " - Initial count of driver packages before starting filtering process: $($DriverPackagesCount)"
		# Filter out driver packages that do not match with the vendor
		Write-CMLogEntry -Value " - Filtering driver package results to detected computer manufacturer: $($ComputerData.Manufacturer)"
		$DriverPackages = $DriverPackages | Where-Object { $_.Manufacturer -like $ComputerData.Manufacturer }
		$DriverPackagesCount = ($DriverPackages | Measure-Object).Count
		Write-CMLogEntry -Value " - Count of driver packages after filter processing: $($DriverPackagesCount)"
		# Filter out driver packages that do not contain any value in the package description
		Write-CMLogEntry -Value " - Filtering driver package results to only include packages that have details added to the description field"
		$DriverPackages = $DriverPackages | Where-Object { $_.Description -ne ([string]::Empty) }
		$DriverPackagesCount = ($DriverPackages | Measure-Object).Count
		Write-CMLogEntry -Value " - Count of driver packages after filter processing: $($DriverPackagesCount)"
		foreach ($DriverPackageItem in $DriverPackages) {
			# Construct custom object to hold values for current driver package properties used for matching with current computer details
			$DriverPackageDetails = [PSCustomObject]@{
				PackageName    = $DriverPackageItem.Name
				PackageID      = $DriverPackageItem.PackageID
				PackageVersion = $DriverPackageItem.Version
				DateCreated    = $DriverPackageItem.SourceDate
				Manufacturer   = $DriverPackageItem.Manufacturer
				Model          = $null
				SystemSKU      = $DriverPackageItem.Description.Split(":").Replace("(", "").Replace(")", "")[1]
				OSName         = $null
				OSVersion      = $null
				Architecture   = $null
			}
			# Add driver package model details depending on manufacturer to custom driver package details object
			# - HP computer models require the manufacturer name to be a part of the model name, other manufacturers do not
			try {
				switch ($DriverPackageItem.Manufacturer) {
					{ @("Hewlett-Packard", "HP") -contains $_ } { $DriverPackageDetails.Model = $DriverPackageItem.Name.Replace("Hewlett-Packard", "HP") }
					default { $DriverPackageDetails.Model = $DriverPackageItem.Name.Replace($DriverPackageItem.Manufacturer, "") }
				}
				$DriverPackageDetails.Model = $DriverPackageDetails.Model.Replace(" - ", ":").Split(":").Trim()[1]
			}
			catch [System.Exception] { Write-CMLogEntry -Value "Failed. Error: $($_.Exception.Message)" -Severity 3 }
			# Add driver package OS architecture details to custom driver package details object
			if ($DriverPackageItem.Name -match "^.*(?<Architecture>(x86|x64)).*") { $DriverPackageDetails.Architecture = $Matches.Architecture }
			# Add driver package OS name details to custom driver package details object
			if ($DriverPackageItem.Name -match "^.*Windows.*(?<OSName>(10)).*") { $DriverPackageDetails.OSName = -join @("Windows ", $Matches.OSName) }
			# Add driver package OS version details to custom driver package details object
			if ($DriverPackageItem.Name -match "^.*Windows.*(?<OSVersion>(\d){4}).*") { $DriverPackageDetails.OSVersion = $Matches.OSVersion }
			# Set counters for logging output of how many matching checks was successfull
			$DetectionCounter = 0
			if ($null -ne $DriverPackageDetails.OSVersion) { $DetectionMethodsCount = 4 } else { $DetectionMethodsCount = 3	}
			Write-CMLogEntry -Value "[DriverPackage:$($DriverPackageDetails.PackageID)]: Processing driver package with $($DetectionMethodsCount) detection methods: $($DriverPackageDetails.PackageName)"
			switch ($ComputerDetectionMethod) {
				"SystemSKU" {
					if ([string]::IsNullOrEmpty($DriverPackageDetails.SystemSKU)) {
						Write-CMLogEntry -Value "[DriverPackage:$($DriverPackageDetails.PackageID)]: Driver package was skipped due to missing SystemSKU values in description field" -Severity 2
					}
					else {
						# Attempt to match against SystemSKU
						$ComputerDetectionMethodResult = Confirm-SystemSKU -DriverPackageInput $DriverPackageDetails.SystemSKU -ComputerData $ComputerData -ErrorAction Stop
						# Fall back to using computer model as the detection method instead of SystemSKU
						if ($ComputerDetectionMethodResult.Detected -eq $false) {
							$ComputerDetectionMethodResult = Confirm-ComputerModel -DriverPackageInput $DriverPackageDetails.Model -ComputerModel $ComputerData.Model
						}
					}
				}
				"ComputerModel" {
					# Attempt to match against computer model
					$ComputerDetectionMethodResult = Confirm-ComputerModel -DriverPackageInput $DriverPackageDetails.Model -ComputerModel $ComputerData.Model
				}
			}
			if ($ComputerDetectionMethodResult.Detected -eq $true) {
				# Increase detection counter since computer detection was successful
				$DetectionCounter++
				# Attempt to match against OS name
				$OSNameDetectionResult = Confirm-OSName -DriverPackageInput $DriverPackageDetails.OSName -OSName $ComputerData.OSName
				if ($OSNameDetectionResult -eq $true) {
					# Increase detection counter since OS name detection was successful
					$DetectionCounter++
					$OSArchitectureDetectionResult = Confirm-Architecture -DriverPackageInput $DriverPackageDetails.Architecture -OSArchitecture $ComputerData.OSArchitecture
					if ($OSArchitectureDetectionResult -eq $true) {
						# Increase detection counter since OS architecture detection was successful
						$DetectionCounter++
						if ($null -ne $DriverPackageDetails.OSVersion) {
							# Handle if OS version should check for fallback versions or match with data from OSImageData variable
							if ($OSVersionFallback -eq $true) {
								$OSVersionDetectionResult = Confirm-OSVersion -DriverPackageInput $DriverPackageDetails.OSVersion -OSImageData $OSImageData -OSVersionFallback $true
							}
							else {
								$OSVersionDetectionResult = Confirm-OSVersion -DriverPackageInput $DriverPackageDetails.OSVersion -OSImageData $OSImageData
							}
							if ($OSVersionDetectionResult -eq $true) {
								# Increase detection counter since OS version detection was successful
								$DetectionCounter++
								# Match found for all critiera including OS version
								Write-CMLogEntry -Value "[DriverPackage:$($DriverPackageItem.PackageID)]: Driver package was created on: $($DriverPackageDetails.DateCreated)"
								Write-CMLogEntry -Value "[DriverPackage:$($DriverPackageItem.PackageID)]: Match found between driver package and computer for $($DetectionCounter)/$($DetectionMethodsCount) checks, adding to list for post-processing of matched driver packages"
								# Update the SystemSKU value for the custom driver package details object to account for multiple values from original driver package data
								if ($ComputerDetectionMethod -like "SystemSKU") {
									$DriverPackageDetails.SystemSKU = $ComputerDetectionMethodResult.SystemSKUValue
								}
								# Add custom driver package details object to list of driver packages for post-processing
								$script:DriverPackageList.Add($DriverPackageDetails) | Out-Null
							}
							else {
								Write-CMLogEntry -Value "[DriverPackage:$($DriverPackageItem.PackageID)]: Skipping driver package since only $($DetectionCounter)/$($DetectionMethodsCount) checks was matched" -Severity 2
							}
						}
						else {
							# Match found for all critiera except for OS version, assuming here that the vendor does not provide OS version specific driver packages
							Write-CMLogEntry -Value "[DriverPackage:$($DriverPackageItem.PackageID)]: Driver package was created on: $($DriverPackageDetails.DateCreated)"
							Write-CMLogEntry -Value "[DriverPackage:$($DriverPackageItem.PackageID)]: Match found between driver package and computer, adding to list for post-processing of matched driver packages"
							# Update the SystemSKU value for the custom driver package details object to account for multiple values from original driver package data
							if ($ComputerDetectionMethod -like "SystemSKU") {
								$DriverPackageDetails.SystemSKU = $ComputerDetectionMethodResult.SystemSKUValue
							}
							# Add custom driver package details object to list of driver packages for post-processing
							$script:DriverPackageList.Add($DriverPackageDetails) | Out-Null
						}
					}
				}
			}
		}
	}
	function Confirm-FallbackDriverPackage {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the computer details object from Get-ComputerDetails function.")]
			[ValidateNotNullOrEmpty()]
			[PSCustomObject]$ComputerData,
			[parameter(Mandatory, HelpMessage = "Specify the OS Image details object from Get-OSImageDetails function.")]
			[ValidateNotNullOrEmpty()]
			[PSCustomObject]$OSImageData,
			[parameter(Mandatory, HelpMessage = "Specify the web service object returned from Connect-WebService function.")]
			[ValidateNotNullOrEmpty()]
			[PSCustomObject]$WebService
		)
		if ($Script:script:DriverPackageList.Count -eq 0) {
			Write-CMLogEntry -Value " - Previous validation process could not find a match for a specific driver package, starting fallback driver package matching process"
			try {
				# Attempt to retrieve fallback driver packages from ConfigMgr WebService
				$FallbackDriverPackages = Get-AdminServiceItem -Resource "/SMS_Package?`$filter=contains(Name,'Driver Fallback Package')" | Where-Object { $_.Name -notmatch "Pilot" -and $_.Name -notmatch "Retired" }
				if ($null -ne $FallbackDriverPackages) {
					Write-CMLogEntry -Value " - Retrieved a total of '$(($FallbackDriverPackages | Measure-Object).Count)' fallback driver packages from web service matching 'Driver Fallback Package' within the name"
					# Sort all fallback driver package objects by package name property
					$FallbackDriverPackages = $FallbackDriverPackages | Sort-Object -Property PackageName
					# Filter out driver packages that does not match with the vendor
					Write-CMLogEntry -Value " - Filtering fallback driver package results to detected computer manufacturer: $($ComputerData.Manufacturer)"
					$FallbackDriverPackages = $FallbackDriverPackages | Where-Object { $_.PackageManufacturer -like $ComputerData.Manufacturer }
					foreach ($DriverPackageItem in $FallbackDriverPackages) {
						# Construct custom object to hold values for current driver package properties used for matching with current computer details
						$DriverPackageDetails = [PSCustomObject]@{
							PackageName  = $DriverPackageItem.PackageName
							PackageID    = $DriverPackageItem.PackageID
							DateCreated  = $DriverPackageItem.PackageCreated
							Manufacturer = $DriverPackageItem.PackageManufacturer
							OSName       = $null
							Architecture = $null
						}
						# Add driver package OS architecture details to custom driver package details object
						if ($DriverPackageItem.PackageName -match "^.*(?<Architecture>(x86|x64)).*") { $DriverPackageDetails.Architecture = $Matches.Architecture }
						# Add driver package OS name details to custom driver package details object
						if ($DriverPackageItem.PackageName -match "^.*Windows.*(?<OSName>(10)).*") { $DriverPackageDetails.OSName = -join @("Windows ", $Matches.OSName) }
						# Set counters for logging output of how many matching checks was successfull
						$DetectionCounter = 0
						$DetectionMethodsCount = 2
						Write-CMLogEntry -Value "[DriverPackageFallback:$($DriverPackageItem.PackageID)]: Processing fallback driver package with $($DetectionMethodsCount) detection methods: $($DriverPackageItem.PackageName)"
						# Attempt to match against OS name
						$OSNameDetectionResult = Confirm-OSName -DriverPackageInput $DriverPackageDetails.OSName -OSName $ComputerDetails.OSName
						if ($OSNameDetectionResult -eq $true) {
							# Increase detection counter since OS name detection was successful
							$DetectionCounter++
							$OSArchitectureDetectionResult = Confirm-Architecture -DriverPackageInput $DriverPackageDetails.Architecture -OSArchitecture $ComputerData.OSArchitecture
							if ($OSArchitectureDetectionResult -eq $true) {
								# Increase detection counter since OS architecture detection was successful
								$DetectionCounter++
								# Match found for all critiera including OS version
								Write-CMLogEntry -Value "[DriverPackageFallback:$($DriverPackageItem.PackageID)]: Fallback driver package was created on: $($DriverPackageDetails.DateCreated)"
								Write-CMLogEntry -Value "[DriverPackageFallback:$($DriverPackageItem.PackageID)]: Match found for fallback driver package with $($DetectionCounter)/$($DetectionMethodsCount) checks, adding to list for post-processing of matched fallback driver packages"
								# Add custom driver package details object to list of fallback driver packages for post-processing
								$script:DriverPackageList.Add($DriverPackageDetails) | Out-Null
							}
						}
					}
				}
				else {
					Write-CMLogEntry -Value " - Retrieved a total of '0' fallback driver packages from web service matching operational mode: $($OperationalMode)" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
			}
			catch [System.Exception] {
				Write-CMLogEntry -Value " - An error occurred while calling ConfigMgr WebService for a list of available fallback driver packages. Error message: $($_.Exception.Message)" -Severity 3
				# Throw terminating error
				New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
			}
		}
		else {
			Write-CMLogEntry -Value " - Driver fallback process will not continue since driver packages matching computer model detection logic of '$($ComputerDetectionMethod)' was found"
			$Script:SkipFallbackDriverPackageValidation = $true
		}
	}
	function Confirm-OSVersion {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the OS version value from the driver package object.")]
			[ValidateNotNullOrEmpty()]
			[string]$DriverPackageInput,
			[parameter(Mandatory, HelpMessage = "Specify the computer data object.")]
			[ValidateNotNullOrEmpty()]
			[PSCustomObject]$OSImageData,
			[parameter(HelpMessage = "Set to True to check for drivers packages that matches earlier versions of Windows than what's detected from web service call.")]
			[ValidateNotNullOrEmpty()]
			[bool]$OSVersionFallback = $false
		)
		if ($OSVersionFallback -eq $true) {
			if ([int]$DriverPackageInput -lt [int]$OSImageData.Version) {
				# OS version match found where driver package input was less than input from OSImageData version
				Write-CMLogEntry -Value " - Matched operating system version: $($DriverPackageInput)"
				return $true
			}
			else {
				# OS version match was not found
				return $false
			}
		}
		else {
			if ($DriverPackageInput -like $OSImageData.Version) {
				# OS version match found
				Write-CMLogEntry -Value " - Matched operating system version: $($OSImageData.Version)"
				return $true
			}
			else {
				# OS version match was not found
				return $false
			}
		}
	}
	function Confirm-Architecture {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the Architecture value from the driver package object.")]
			[ValidateNotNullOrEmpty()]
			[string]$DriverPackageInput,
			[parameter(Mandatory, HelpMessage = "Specify the computer data object.")]
			[ValidateNotNullOrEmpty()]
			[string]$OSArchitecture
		)
		if ($DriverPackageInput -like $OSArchitecture) {
			# OS architecture match found
			Write-CMLogEntry -Value " - Matched operating system architecture: $($OSArchitecture)"
			return $true
		}
		else {
			# OS architecture match was not found
			return $false
		}
	}
	function Confirm-OSName {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the OS name value from the driver package object.")]
			[ValidateNotNullOrEmpty()]
			[string]$DriverPackageInput,
			[parameter(Mandatory, HelpMessage = "Specify the computer data object.")]
			[ValidateNotNullOrEmpty()]
			[string]$OSName
		)
		if ($DriverPackageInput -like $OSName) {
			# OS name match found
			Write-CMLogEntry -Value " - Matched operating system name: $($OSName)"
			return $true
		}
		else {
			# OS name match was not found
			return $false
		}
	}
	function Confirm-ComputerModel {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the computer model value from the driver package object.")]
			[ValidateNotNullOrEmpty()]
			[string]$DriverPackageInput,
			[parameter(Mandatory, HelpMessage = "Specify the computer data object.")]
			[ValidateNotNullOrEmpty()]
			[string]$ComputerModel
		)
		# Construct custom object for return value
		$ModelDetectionResult = [PSCustomObject]@{ Detected = $null }
		if ($DriverPackageInput -like $ComputerModel) {
			# Computer model match found
			Write-CMLogEntry -Value " - Matched computer model: $($ComputerModel)"
			# Set properties for custom object for return value
			$ModelDetectionResult.Detected = $true
			return $ModelDetectionResult
		}
		else {
			# Computer model match was not found
			# Set properties for custom object for return value
			$ModelDetectionResult.Detected = $false
			return $ModelDetectionResult
		}
	}
	function Confirm-SystemSKU {
		param(
			[parameter(Mandatory, HelpMessage = "Specify the SystemSKU value from the driver package object.")]
			[ValidateNotNullOrEmpty()]
			[string]$DriverPackageInput,
			[parameter(Mandatory, HelpMessage = "Specify the computer data object.")]
			[ValidateNotNullOrEmpty()]
			[PSCustomObject]$ComputerData
		)
		# Handle multiple SystemSKU's from driver package input and determine the proper delimiter
		if ($DriverPackageInput -match ",") { $SystemSKUDelimiter = ","	}
		if ($DriverPackageInput -match ";") { $SystemSKUDelimiter = ";" }
		# Remove any space characters from driver package input data, replace them with a comma instead and ensure there's no duplicate entries
		$DriverPackageInputArray = $DriverPackageInput.Replace(" ", ",").Split($SystemSKUDelimiter) | Select-Object -Unique
		# Construct custom object for return value
		$SystemSKUDetectionResult = [PSCustomObject]@{
			Detected       = $null
			SystemSKUValue = $null
		}
		# Attempt to determine if the driver package input matches with the computer data input and account for multiple SystemSKU's by separating them with the detected delimiter
		if (-not([string]::IsNullOrEmpty($SystemSKUDelimiter))) {
			# Construct table for keeping track of matched SystemSKU items
			$SystemSKUTable = @{}
			# Attempt to match for each SystemSKU item based on computer data input
			foreach ($SystemSKUItem in $DriverPackageInputArray) {
				if ($ComputerData.SystemSKU -match $SystemSKUItem) {
					# Add key value pair with match success
					$SystemSKUTable.Add($SystemSKUItem, $true)
					# Set custom object property with SystemSKU value that was matched on the detection result object
					$SystemSKUDetectionResult.SystemSKUValue = $SystemSKUItem
				}
				else {
					# Add key value pair with match failure
					$SystemSKUTable.Add($SystemSKUItem, $false)
				}
			}
			# Check if table contains a matched SystemSKU
			if ($SystemSKUTable.Values -contains $true) {
				# SystemSKU match found based upon multiple items detected in computer data input
				Write-CMLogEntry -Value " - Matched SystemSKU: $($ComputerData.SystemSKU)"
				# Set custom object property that SystemSKU value that was matched on the detection result object
				$SystemSKUDetectionResult.Detected = $true
				return $SystemSKUDetectionResult
			}
			else {
				# SystemSKU match was not found based upon multiple items detected in computer data input
				# Set properties for custom object for return value
				$SystemSKUDetectionResult.SystemSKUValue = ""
				$SystemSKUDetectionResult.Detected = $false
				return $SystemSKUDetectionResult
			}
		}
		elseif ($DriverPackageInput -match $ComputerData.SystemSKU) {
			# SystemSKU match found based upon single item detected in computer data input
			Write-CMLogEntry -Value " - Matched SystemSKU: $($ComputerData.SystemSKU)"
			# Set properties for custom object for return value
			$SystemSKUDetectionResult.SystemSKUValue = $ComputerData.SystemSKU
			$SystemSKUDetectionResult.Detected = $true
			return $SystemSKUDetectionResult
		}
		elseif ((-not([string]::IsNullOrEmpty($ComputerData.FallbackSKU))) -and ($DriverPackageInput -match $ComputerData.FallbackSKU)) {
			# SystemSKU match found using FallbackSKU value using detection method OEMString, this should only be valid for Dell
			Write-CMLogEntry -Value " - Matched SystemSKU: $($ComputerData.FallbackSKU)"
			# Set properties for custom object for return value
			$SystemSKUDetectionResult.SystemSKUValue = $ComputerData.FallbackSKU
			$SystemSKUDetectionResult.Detected = $true
			return $SystemSKUDetectionResult
		}
		else {
			# None of the above methods worked to match SystemSKU from driver package input with computer data input
			# Set properties for custom object for return value
			$SystemSKUDetectionResult.SystemSKUValue = ""
			$SystemSKUDetectionResult.Detected = $false
			return $SystemSKUDetectionResult
		}
	}
	function Confirm-DriverPackageList {
		Write-CMLogEntry -Value "[DriverPackageValidation]: Starting driver package validation phase"
		switch ($script:DriverPackageList.Count) {
			0 {
				Write-CMLogEntry -Value " - Amount of driver packages detected by validation process: $($script:DriverPackageList.Count)" -Severity 2
				if ($Script:PSBoundParameters["OSVersionFallback"]) {
					Write-CMLogEntry -Value " - Validation process detected empty list of matched driver packages, however OSVersionFallback switch was passed on the command line" -Severity 2
					Write-CMLogEntry -Value " - Starting re-matching process of driver packages for older Windows versions"
					# Attempt to match all drivers packages again but this time where OSVersion from driver packages is lower than what's detected from web service call
					Write-CMLogEntry -Value "[DriverPackageFallback]: Starting driver package OS version fallback matching phase"
					Confirm-DriverPackage -ComputerData $ComputerData -OSImageData $OSImageDetails -DriverPackage $DriverPackages -OSVersionFallback $true
					if ($script:DriverPackageList.Count -ge 1) {
						# Sort driver packages descending based on OSVersion, DateCreated properties and select the most recently created one
						$Script:script:DriverPackageList = $script:DriverPackageList | Sort-Object -Property OSVersion, DateCreated -Descending | Select-Object -First 1
						Write-CMLogEntry -Value " - Selected driver package '$($script:DriverPackageList[0].PackageID)' with name: $($script:DriverPackageList[0].PackageName)"
						Write-CMLogEntry -Value " - Successfully completed validation after fallback process and detected a single driver package, script execution is allowed to continue"
						Write-CMLogEntry -Value "[DriverPackageFallback]: Completed driver package OS version fallback matching phase"
					}
					else {
						if ($Script:PSBoundParameters["UseDriverFallback"]) {
							Write-CMLogEntry -Value " - Validation process detected an empty list of matched driver packages, however the UseDriverFallback parameter was specified"
						}
						else {
							Write-CMLogEntry -Value " - Validation after fallback process failed with empty list of matched driver packages, script execution will be terminated" -Severity 3
							# Throw terminating error
							New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
						}
					}
				}
				else {
					if ($Script:PSBoundParameters["UseDriverFallback"]) {
						Write-CMLogEntry -Value " - Validation process detected an empty list of matched driver packages, however the UseDriverFallback parameter was specified"
					}
					else {
						Write-CMLogEntry -Value " - Validation failed with empty list of matched driver packages, script execution will be terminated" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
				}
			}
			1 {
				Write-CMLogEntry -Value " - Amount of driver packages detected by validation process: $($script:DriverPackageList.Count)"
				Write-CMLogEntry -Value " - Successfully completed validation with a single driver package, script execution is allowed to continue"
			}
			default {
				Write-CMLogEntry -Value " - Amount of driver packages detected by validation process: $($script:DriverPackageList.Count)"
				if ($ComputerDetectionMethod -like "SystemSKU") {
					if ($null -eq ($script:DriverPackageList | Where-Object { $_.SystemSKU -notlike $script:DriverPackageList[0].SystemSKU })) {
						Write-CMLogEntry -Value " - NOTICE: Computer detection method is currently '$($ComputerDetectionMethod)', and multiple packages have been matched with the same SystemSKU value"
						Write-CMLogEntry -Value " - NOTICE: This is a supported scenario where the vendor use the same driver package for multiple models"
						Write-CMLogEntry -Value " - NOTICE: Validation process will automatically choose the most recently created driver package, even if it means that the computer model names may not match"
						# Sort driver packages descending based on DateCreated property and select the most recently created one
						$script:DriverPackageList = $script:DriverPackageList | Sort-Object -Property DateCreated -Descending | Select-Object -First 1
						Write-CMLogEntry -Value " - Selected driver package '$($script:DriverPackageList[0].PackageID)' with name: $($script:DriverPackageList[0].PackageName)"
						Write-CMLogEntry -Value " - Successfully completed validation with multiple detected driver packages, script execution is allowed to continue"
					}
					else {
						# This should not be possible, but added to handle output to log file for user to reach out to the developers
						Write-CMLogEntry -Value " - WARNING: Computer detection method is currently '$($ComputerDetectionMethod)', and multiple packages have been matched but with different SystemSKU value" -Severity 2
						Write-CMLogEntry -Value " - WARNING: This should not be a possible scenario, please reach out to the developers of this script" -Severity 2
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
				}
				else {
					Write-CMLogEntry -Value " - NOTICE: Computer detection method is currently '$($ComputerDetectionMethod)', and multiple packages have been matched with the same Model value"
					Write-CMLogEntry -Value " - NOTICE: Validation process will automatically choose the most recently created driver package by the DateCreated property"
					# Sort driver packages descending based on DateCreated property and select the most recently created one
					$script:DriverPackageList = $script:DriverPackageList | Sort-Object -Property DateCreated -Descending | Select-Object -First 1
					Write-CMLogEntry -Value " - Selected driver package '$($script:DriverPackageList[0].PackageID)' with name: $($script:DriverPackageList[0].PackageName)"
				}
			}
		}
		Write-CMLogEntry -Value "[DriverPackageValidation]: Completed driver package validation phase"
	}
	function Confirm-FallbackDriverPackageList {
		if ($Script:SkipFallbackDriverPackageValidation -eq $false) {
			switch ($script:DriverPackageList.Count) {
				0 {
					Write-CMLogEntry -Value " - Amount of fallback driver packages detected by validation process: $($script:DriverPackageList.Count)" -Severity 3
					Write-CMLogEntry -Value " - Validation failed with empty list of matched fallback driver packages, script execution will be terminated" -Severity 3
					# Throw terminating error
					New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
				}
				1 {
					Write-CMLogEntry -Value " - Amount of fallback driver packages detected by validation process: $($script:DriverPackageList.Count)"
					Write-CMLogEntry -Value " - Successfully completed validation with a single driver package, script execution is allowed to continue"
				}
				default {
					Write-CMLogEntry -Value " - Amount of fallback driver packages detected by validation process: $($script:DriverPackageList.Count)"
					Write-CMLogEntry -Value " - NOTICE: Multiple fallback driver packages have been matched, validation process will automatically choose the most recently created fallback driver package by the DateCreated property"
					# Sort driver packages descending based on DateCreated property and select the most recently created one
					$Script:DriverPackageList = $script:DriverPackageList | Sort-Object -Property DateCreated -Descending | Select-Object -First 1
					Write-CMLogEntry -Value " - Selected fallback driver package '$($script:DriverPackageList[0].PackageID)' with name: $($script:DriverPackageList[0].PackageName)"
				}
			}
		}
		else {
			Write-CMLogEntry -Value " - Fallback driver package validation process is being skipped since 'SkipFallbackDriverPackageValidation' variable was set to True"
		}
	}
	function Invoke-DownloadDriverPackageContent {
		Write-CMLogEntry -Value " - Attempting to download content files for matched driver package: $($script:DriverPackageList[0].PackageName)"
		# Depending on current deployment type, attempt to download driver package content
		switch ($Script:PSCmdlet.ParameterSetName) {
			"PreCache" {
				if ($Script:PSBoundParameters["PreCachePath"]) {
					if (-not(Test-Path -Path $Script:PreCachePath)) {
						Write-CMLogEntry -Value " - Attempting to create PreCachePath directory, as it doesn't exist: $($Script:PreCachePath)"
						try { New-Item -Path $PreCachePath -ItemType Directory -Force -ErrorAction Stop | Out-Null }
						catch [System.Exception] {
							Write-CMLogEntry -Value " - Failed to create PreCachePath directory '$($Script:PreCachePath)'. Error message: $($_.Exception.Message)" -Severity 3
							# Throw terminating error
							New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
						}
					}
					if (Test-Path -Path $Script:PreCachePath) {
						$DownloadInvocation = Invoke-CMDownloadContent -PackageID $script:DriverPackageList[0].PackageID -DestinationLocationType "Custom" -DestinationVariableName "OSDDriverPackage" -CustomLocationPath "$($Script:PreCachePath)"
					}
				}
				else {
					$DownloadInvocation = Invoke-CMDownloadContent -PackageID $script:DriverPackageList[0].PackageID -DestinationLocationType "CCMCache" -DestinationVariableName "OSDDriverPackage"
				}
			}
			default {
				$DownloadInvocation = Invoke-CMDownloadContent -PackageID $script:DriverPackageList[0].PackageID -DestinationLocationType "Custom" -DestinationVariableName "OSDDriverPackage" -CustomLocationPath "%_SMSTSMDataPath%\DriverPackage"
			}
		}
		# If download process was successful, meaning exit code from above function was 0, return the download location path
		if ($DownloadInvocation -eq 0) {
			$DriverPackageContentLocation = $Script:TSEnvironment.Value("OSDDriverPackage01")
			Write-CMLogEntry -Value " - Driver package content files was successfully downloaded to: $($DriverPackageContentLocation)"
			# Handle return value for successful download of driver package content files
			return $DriverPackageContentLocation
		}
		else {
			Write-CMLogEntry -Value " - Driver package content download process returned an unhandled exit code: $($DownloadInvocation)" -Severity 3
			# Throw terminating error
			New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
		}
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
						Write-CMLogEntry -Value " - Attempting to decompress driver package content file: $($DriverPackageCompressedFile.Name)"
						Write-CMLogEntry -Value " - Decompression destination: $($ContentLocation)"
						Expand-Archive -Path $DriverPackageCompressedFile.FullName -DestinationPath $ContentLocation -Force -ErrorAction Stop
						Write-CMLogEntry -Value " - Successfully decompressed driver package content file"
					}
					catch [System.Exception] {
						Write-CMLogEntry -Value " - Failed to decompress driver package content file. Error message: $($_.Exception.Message)" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
					try {
						# Remove compressed driver package archive file
						if (Test-Path -Path $DriverPackageCompressedFile.FullName) {
							Remove-Item -Path $DriverPackageCompressedFile.FullName -Force -ErrorAction Stop
						}
					}
					catch [System.Exception] {
						Write-CMLogEntry -Value " - Failed to remove compressed driver package content file after decompression. Error message: $($_.Exception.Message)" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
				}
				"*.exe" {
					Write-CMLogEntry -Value " - Attempting to decompress 7-Zip driver package content file: $($DriverPackageCompressedFile.Name)"
					Write-CMLogEntry -Value " - Decompression destination: $($ContentLocation)"
					$ReturnCode = Invoke-Executable -FilePath $DriverPackageCompressedFile.FullName -Arguments "-o`"$($ContentLocation)`" -y"
					# Validate 7-Zip driver extraction
					if ($ReturnCode -eq 0) {
						Write-CMLogEntry -Value " - Successfully decompressed 7-Zip driver package content file"
					}
					else {
						Write-CMLogEntry -Value " - An error occurred while decompressing 7-Zip driver package content file. Return code from self-extracing executable: $($ReturnCode)" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
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
						Write-CMLogEntry -Value " - Failed to create mount location for WIM file. Error message: $($_.Exception.Message)" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
					try {
						# Expand compressed driver package WIM file
						Write-CMLogEntry -Value " - Attempting to mount driver package content WIM file: $($DriverPackageCompressedFile.Name)"
						Write-CMLogEntry -Value " - Mount location: $($DriverPackageMountLocation)"
						Mount-WindowsImage -ImagePath $DriverPackageCompressedFile.FullName -Path $DriverPackageMountLocation -Index 1 -ErrorAction Stop
						Write-CMLogEntry -Value " - Successfully mounted driver package content WIM file"
						Write-CMLogEntry -Value " - Copying items from mount directory"
						Get-ChildItem -Path	$DriverPackageMountLocation | Copy-Item -destination $ContentLocation -Recurse -container
					}
					catch [System.Exception] {
						Write-CMLogEntry -Value " - Failed to mount driver package content WIM file. Error message: $($_.Exception.Message)" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
				}
			}
		}
		switch ($Script:PSCmdlet.ParameterSetName) {
			"BareMetal" {
				# Apply drivers recursively from downloaded driver package location
				Write-CMLogEntry -Value " - Attempting to apply drivers using dism.exe located in: $($ContentLocation)"
				# Determine driver injection method from parameter input
				switch ($DriverInstallMode) {
					"Single" {
						try {
							Write-CMLogEntry -Value " - DriverInstallMode is currently set to: $($DriverInstallMode)"
							# Get driver full path and install each driver seperately
							$DriverINFs = Get-ChildItem -Path $ContentLocation -Recurse -Filter "*.inf" -ErrorAction Stop | Select-Object -Property FullName, Name
							if ($null -ne $DriverINFs) {
								foreach ($DriverINF in $DriverINFs) {
									# Install specific driver
									Write-CMLogEntry -Value " - Attempting to install driver: $($DriverINF.FullName)"
									$ApplyDriverInvocation = Invoke-Executable -FilePath "dism.exe" -Arguments "/Image:$($Script:TSEnvironment.Value('OSDTargetSystemDrive'))\ /Add-Driver /Driver:`"$($DriverINF.FullName)`""
									# Validate driver injection
									if ($ApplyDriverInvocation -eq 0) {
										Write-CMLogEntry -Value " - Successfully installed driver using dism.exe"
									}
									else {
										Write-CMLogEntry -Value " - An error occurred while installing driver. Continuing with warning code: $($ApplyDriverInvocation). See DISM.log for more details" -Severity 2
									}
								}
							}
							else {
								Write-CMLogEntry -Value " - An error occurred while enumerating driver paths, downloaded driver package does not contain any INF files" -Severity 3
								# Throw terminating error
								New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
							}
						}
						catch [System.Exception] {
							Write-CMLogEntry -Value " - An error occurred while installing drivers. See DISM.log for more details" -Severity 2
							# Throw terminating error
							New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
						}
					}
					"Recurse" {
						Write-CMLogEntry -Value " - DriverInstallMode is currently set to: $($DriverInstallMode)"
						# Apply drivers recursively
						$ApplyDriverInvocation = Invoke-Executable -FilePath "dism.exe" -Arguments "/Image:$($Script:TSEnvironment.Value('OSDTargetSystemDrive'))\ /Add-Driver /Driver:$($ContentLocation) /Recurse"
						# Validate driver injection
						if ($ApplyDriverInvocation -eq 0) {
							Write-CMLogEntry -Value " - Successfully installed drivers recursively in driver package content location using dism.exe"
						}
						else {
							Write-CMLogEntry -Value " - An error occurred while installing drivers. Continuing with warning code: $($ApplyDriverInvocation). See DISM.log for more details" -Severity 2
						}
					}
				}
			}
			"OSUpgrade" {
				# For OSUpgrade, don't attempt to install drivers as this is handled by setup.exe when used together with OSDUpgradeStagedContent
				Write-CMLogEntry -Value " - Driver package content downloaded successfully and located in: $($ContentLocation)"
				# Set OSDUpgradeStagedContent task sequence variable
				Write-CMLogEntry -Value " - Attempting to set OSDUpgradeStagedContent task sequence variable with value: $($ContentLocation)"
				$Script:TSEnvironment.Value("OSDUpgradeStagedContent") = "$($ContentLocation)"
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
						Write-CMLogEntry -Value " - Attempting to dismount driver package content WIM file: $($DriverPackageCompressedFile.Name)"
						Write-CMLogEntry -Value " - Mount location: $($DriverPackageMountLocation)"
						Dismount-WindowsImage -Path $DriverPackageMountLocation -Discard -ErrorAction Stop
						Write-CMLogEntry -Value " - Successfully dismounted driver package content WIM file"
					}
					catch [System.Exception] {
						Write-CMLogEntry -Value " - Failed to dismount driver package content WIM file. Error message: $($_.Exception.Message)" -Severity 3
						# Throw terminating error
						New-TerminatingErrorRecord -Message ([string]::Empty) -ThrowError
					}
				}
			}
		}
	}
}#begin

End {
	if (-not $DebugMode.IsPresent) {
		# Reset OSDDownloadContent.exe dependant variables for further use of the task sequence step
		Invoke-CMResetDownloadContentVariables
	}
	# Write final output to log file
	Write-CMLogEntry -Value "[ApplyDriverPackage]: Completed Apply Driver Package process"
	Out-File -FilePath $LogFilePath -InputObject $script:LogEntries -Encoding default -NoClobber -Force
}
