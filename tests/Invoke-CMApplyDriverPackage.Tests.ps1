$ErrorActionPreference = "Stop"
$ScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Invoke-CMApplyDriverPackage.ps1"
$ParseErrors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$ParseErrors)
if ($ParseErrors.Count) { throw ($ParseErrors.Message -join "; ") }

foreach ($Name in @("Get-OSBuild", "Get-ComputerSystemType", "Confirm-SystemSKU", "Get-DeploymentType", "New-TerminatingErrorRecord", "Test-VirtualMachineDriverPackage", "Read-DriverPackageLogicFile")) {
    $Node = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq $Name }.GetNewClosure(), $true)
    Invoke-Expression $Node.Extent.Text
}
$Node = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.AssignmentStatementAst] -and $Item.Left.Extent.Text -eq '$Script:VirtualMachinePackagePattern' }, $true)
Invoke-Expression $Node.Extent.Text
function Write-CMLogEntry { param($Value, $Severity) }
function Get-ItemProperty {
    param($Path, $Name, $ErrorAction)
    if ($Script:DisplayVersionThrows) { throw "DisplayVersion unavailable" }
    [pscustomobject]@{ DisplayVersion = $Script:DisplayVersion }
}
function Get-WmiObject { param($Class) $Script:TestSystem }
foreach ($Case in @(
    @("10.0.26300.1", "26H2"),
    @("10.0.28000.1", "26H1"),
    @("10.0.26200.1", "25H2")
)) {
    if ((Get-OSBuild -InputObject $Case[0] -OSName "Windows 11") -ne $Case[1]) {
        throw "Incorrect Windows 11 build mapping: $($Case -join ', ')"
    }
}
$Script:DisplayVersion = "27H1"
$Script:DisplayVersionThrows = $false
if ((Get-OSBuild -InputObject "10.0.29000.1" -OSName "Windows 11") -ne "27H1") {
    throw "DisplayVersion fallback failed"
}
foreach ($Fallback in @(
    @{ Value = "Preview"; Throws = $false },
    @{ Value = $null; Throws = $true }
)) {
    $Script:DisplayVersion = $Fallback.Value
    $Script:DisplayVersionThrows = $Fallback.Throws
    $Blocked = $false
    try { Get-OSBuild -InputObject "10.0.29000.1" -OSName "Windows 11" } catch { $Blocked = $true }
    if (-not $Blocked) { throw "Invalid or missing DisplayVersion did not fail closed" }
}
function Test-Platform {
    [CmdletBinding(DefaultParameterSetName = "BareMetal")]
    param([Parameter(ParameterSetName = "Debug")][switch]$DebugMode)
    $Script:PSCmdlet = $PSCmdlet
    Get-ComputerSystemType
}
$Cases = @(
    @("VMware7,1", "VMware, Inc.", "Hypervisor-VMware"),
    @("VMware 22,1", "VMware, Inc.", "Hypervisor-VMware"),
    @("Virtual Machine", "Microsoft Corporation", "Hypervisor-HyperV"),
    @("Parallels Virtual Platform", "Parallels Software International Inc.", "Hypervisor-Parallels"),
    @("AHV Virtual Machine", "Nutanix", "Hypervisor-NutanixAHV"),
    @("VirtualBox", "Oracle Corporation", "Hypervisor-VirtualBox"),
    @("Standard PC (Q35 + ICH9, 2009)", "QEMU", "Hypervisor-QEMUKVM"),
    @("KVM Virtual Machine", "Red Hat", "Hypervisor-QEMUKVM"),
    @("Standard PC (Q35 + ICH9, 2009)", "Contoso", "Physical-Unknown"),
    @("XenEnterprise", "Xen", "Hypervisor-XenCitrix"),
    @("HVM domU", "Citrix", "Hypervisor-XenCitrix"),
    @("Surface Pro", "Microsoft Corporation", "OEM-Surface"),
    @("Latitude", "Dell", "OEM-Dell"),
    @("B360", "Getac Technology Corporation", "OEM-Getac"),
    @("Prestige 16 AI Studio", "Micro-Star International Co., Ltd.", "OEM-MSI"),
    @("PRO DP21 14M", "MSI", "OEM-MSI"),
    @("G5 KF5", "GIGABYTE TECHNOLOGY CO., LTD.", "OEM-GIGABYTE"),
    @("PORTEGE X40-K", "Dynabook Inc.", "OEM-Dynabook"),
    @("TECRA A50", "TOSHIBA", "OEM-Dynabook"),
    @("Alienware m18", "Dell Inc.", "OEM-Alienware"),
    @("EliteBook", "Hewlett-Packard", "OEM-HP"),
    @("ExpertBook", "ASUSTeK COMPUTER INC.", "OEM-ASUS"),
    @("NUC13", "Intel", "OEM-IntelNUC"),
    @("Server", "Red Hat", "Physical-Unknown"),
    @("Virtual Machine", "Contoso", "Physical-Unknown")
)
foreach ($Case in $Cases) {
    $Script:TestSystem = [pscustomobject]@{ Model = $Case[0]; Manufacturer = $Case[1] }
    $AllowVirtualMachine = $true
    Test-Platform
    if ($Script:ComputerPlatform -ne $Case[2]) { throw "Incorrect platform: $($Case -join ', ')" }
    $AllowVirtualMachine = $false
    if ($Case[2] -like "Hypervisor-*") {
        $Blocked = $false
        try { Test-Platform } catch { if ($_.Exception.Message -ne "InnerTerminatingFailure") { throw }; $Blocked = $true }
        if (-not $Blocked) { throw "Virtual platform bypassed opt-in" }
        Test-Platform -DebugMode
    }
    else { Test-Platform }
}

$ComputerDataNode = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq "Get-ComputerData" }, $true)
Invoke-Expression $ComputerDataNode.Extent.Text
function Get-CimInstance { param($ClassName, $NameSpace) $Script:TestSystemInformation }
function Get-WmiObject {
    param($Class, $Namespace)
    if ($Class -eq "Win32_BaseBoard") { return $Script:TestBaseBoard }
    return $Script:TestSystem
}
function Test-ComputerData {
    [CmdletBinding()]param()
    $Script:PSCmdlet = $PSCmdlet
    Get-ComputerData
}
$Script:TestSystem = [pscustomobject]@{ Model = "FZ-55"; Manufacturer = "Panasonic Corporation" }
$Script:TestSystemInformation = [pscustomobject]@{ BaseBoardProduct = "FZ55-3" }
$ComputerData = Test-ComputerData
if ($ComputerData.Manufacturer -ne "Panasonic" -or $ComputerData.Model -ne "FZ-55" -or $ComputerData.SystemSKU -ne "FZ55-3") {
    throw "Panasonic package normalization failed"
}
$Script:TestSystem = [pscustomobject]@{ Model = "B360"; Manufacturer = "Getac Technology Corporation" }
$Script:TestSystemInformation = [pscustomobject]@{ BaseBoardProduct = "B360G3" }
$ComputerData = Test-ComputerData
if ($ComputerData.Manufacturer -ne "Getac" -or $ComputerData.Model -ne "B360" -or $ComputerData.SystemSKU -ne "B360G3") {
    throw "Getac package normalization failed"
}
foreach ($Case in @(
    @("Prestige 16 AI Studio", "Micro-Star International Co., Ltd.", "MSI"),
    @("PRO DP21 14M", "MSI", "MSI"),
    @("G5 KF5", "GIGABYTE TECHNOLOGY CO., LTD.", "GIGABYTE"),
    @("PORTEGE X40-K", "Dynabook Inc.", "Dynabook"),
    @("TECRA A50", "TOSHIBA", "Dynabook")
)) {
    $Script:TestSystem = [pscustomobject]@{ Model = $Case[0]; Manufacturer = $Case[1] }
    $Script:TestSystemInformation = [pscustomobject]@{}
    $ComputerData = Test-ComputerData
    if ($ComputerData.Manufacturer -ne $Case[2] -or $ComputerData.Model -ne $Case[0] -or $null -ne $ComputerData.SystemSKU) {
        throw "Manual OEM package normalization failed: $($Case -join ', ')"
    }
}
$Script:TestSystem = [pscustomobject]@{ Model = "LIFEBOOK U7412"; Manufacturer = "FUJITSU CLIENT COMPUTING LIMITED" }
$Script:TestBaseBoard = [pscustomobject]@{ SKU = $null }
$ComputerData = Test-ComputerData
if ($ComputerData.Manufacturer -ne "Fujitsu" -or $ComputerData.Model -ne "LIFEBOOK U7412" -or $null -ne $ComputerData.SystemSKU) {
    throw "Fujitsu null-SKU model fallback failed"
}
$Script:TestSystem = [pscustomobject]@{ Model = "AHV Virtual Machine"; Manufacturer = "" }
$Script:TestSystemInformation = [pscustomobject]@{
    SystemManufacturer = "Nutanix"
    SystemProductName = "AHV Virtual Machine"
    SystemSKU = "AHV-SKU"
}
$ComputerData = Test-ComputerData
if ($ComputerData.Manufacturer -ne "Nutanix" -or $ComputerData.Model -ne "AHV Virtual Machine" -or $ComputerData.SystemSKU -ne "AHV-SKU") {
    throw "Nutanix MS_SystemInformation fallback failed"
}

foreach ($Case in @(
    @("42", "42", $true), @("142", "42", $false), @("ModelSKU-42", "42", $false),
    @("42;43,44 45", "44", $true), @("42;43,44 45", "45", $true),
    @("A[1]", "A[1]", $true), @("A1", "A[1]", $false), @("42", "", $false)
)) {
    $Result = Confirm-SystemSKU -DriverPackageInput $Case[0] -ComputerData ([pscustomobject]@{ SystemSKU = $Case[1]; FallbackSKU = "" })
    if ($Result.Detected -ne $Case[2]) { throw "Incorrect SKU match: $($Case -join ', ')" }
}
$Result = Confirm-SystemSKU -DriverPackageInput "42;43" -ComputerData ([pscustomobject]@{ SystemSKU = ""; FallbackSKU = "43" })
if (-not $Result.Detected -or $Result.SystemSKUValue -ne "43") { throw "Fallback SKU failed" }

function Test-Path { param($Path) $Script:XmlExists }
$TSEnvironment = New-Object PSObject
$TSEnvironment | Add-Member ScriptMethod Value { param($Name) "C:\Package" }
function Test-Deployment {
    [CmdletBinding(DefaultParameterSetName = "XMLPackage")]
    param()
    $Script:PSCmdlet = $PSCmdlet
    Get-DeploymentType
}
$Script:XmlExists = $true
foreach ($Mode in @("OSUpdate", "OSUpgrade", "BareMetal", "DriverUpdate", "PreCache")) {
    $Script:XMLDeploymentType = $Mode
    Test-Deployment
    $Expected = $Mode
    if ($Mode -eq "OSUpdate") { $Expected = "OSUpgrade" }
    if ($Script:DeploymentMode -ne $Expected) { throw "Incorrect XML deployment mode" }
}
$Script:XmlExists = $false
$Blocked = $false
try { Test-Deployment } catch { if ($_.Exception.Message -ne "InnerTerminatingFailure") { throw }; $Blocked = $true }
if (-not $Blocked) { throw "Missing XML file did not stop deployment" }

$XmlPath = Join-Path $env:TEMP ("mdm-logic-" + [guid]::NewGuid().ToString() + ".xml")
try {
    Set-Content -LiteralPath $XmlPath -Value "<ArrayOfCMPackage><CMPackage><Name>Drivers</Name></CMPackage></ArrayOfCMPackage>" -Encoding UTF8
    $Document = Read-DriverPackageLogicFile -Path $XmlPath
    if ($Document.ArrayOfCMPackage.CMPackage.Name -ne "Drivers") { throw "Safe XML package parsing failed" }
    Set-Content -LiteralPath $XmlPath -Value '<!DOCTYPE x [<!ENTITY e SYSTEM "file:///C:/Windows/win.ini">]><ArrayOfCMPackage><CMPackage><Name>&e;</Name></CMPackage></ArrayOfCMPackage>' -Encoding UTF8
    $Blocked = $false
    try { Read-DriverPackageLogicFile -Path $XmlPath } catch { $Blocked = $true }
    if (-not $Blocked) { throw "XML DTD processing was not blocked" }
}
finally {
    Remove-Item -LiteralPath $XmlPath -Force -ErrorAction SilentlyContinue
}

$InstallNode = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq "Install-DriverPackageContent" }, $true)
$SwitchNode = $InstallNode.Find({ param($Item) $Item -is [System.Management.Automation.Language.SwitchStatementAst] -and $Item.Condition.Extent.Text -eq '$Script:DeploymentMode' }, $true)
$DismountNodes = $InstallNode.FindAll({ param($Item) $Item -is [System.Management.Automation.Language.CommandAst] -and $Item.GetCommandName() -eq "Dismount-WindowsImage" }, $true)
if ($DismountNodes.Count -ne 2 -or ($DismountNodes | Where-Object { $_.Extent.EndOffset -gt $SwitchNode.Extent.StartOffset })) {
    throw "WIM content can remain mounted while driver processing starts"
}
if ($InstallNode.Extent.Text -notmatch '/LogPath:`"\$\(\$DismLogPath\)`"' -or
    $InstallNode.Extent.Text -notmatch '/Driver:`"\$\(\$ContentLocation\)`" /Recurse') {
    throw "DISM paths are not quoted or logged consistently"
}
Invoke-Expression $InstallNode.Extent.Text
$Script:DeploymentMode = "PreCache"
Install-DriverPackageContent -ContentLocation "Z:\Path-That-Must-Not-Be-Read"

$UpdateClause = $SwitchNode.Clauses | Where-Object { $_.Item1.Value -eq "DriverUpdate" }
$UpdateBlock = [scriptblock]::Create($UpdateClause.Item2.Extent.Text.TrimStart("{").TrimEnd("}"))
function Invoke-Executable { param($FilePath, $Arguments) $Script:InstallArguments = $Arguments; $Script:InstallExitCode }
function Test-Install {
    [CmdletBinding()]param()
    & $UpdateBlock
}
$ContentLocation = "C:\Driver Packs\O'Brien"
$LogsDirectory = "C:\Deployment Logs"
foreach ($Code in @(0, 3010, 5, -1)) {
    $Script:InstallExitCode = $Code
    $Failed = $false
    try { Test-Install } catch { if ($_.Exception.Message -ne "InnerTerminatingFailure") { throw }; $Failed = $true }
    if ($Failed -ne ($Code -notin @(0, 3010))) { throw "Incorrect installation exit handling: $Code" }
}
$Command = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String(($Script:InstallArguments -split " ")[-1]))
$CommandErrors = $null
[System.Management.Automation.Language.Parser]::ParseInput($Command, [ref]$null, [ref]$CommandErrors) | Out-Null
if ($CommandErrors.Count -or $Command -notlike '*exit $LASTEXITCODE*' -or -not $Command.Contains("O''Brien")) { throw "Installer command quoting or exit propagation failed" }
foreach ($Label in @("VMware7,1", "Citrix", "XenServer", "Proxmox", "VirtIO", "Parallels", "Nutanix", "AHV")) {
    if (-not (Test-VirtualMachineDriverPackage -Package ([pscustomobject]@{ Name = "Drivers - $Label - Windows 11 26H2 Arm64" }))) { throw "VM package label rejected" }
}
$AuthNode = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq "Get-AuthToken" }, $true)
Invoke-Expression $AuthNode.Extent.Text
function Invoke-RestMethod {
    param($Method, $Uri, $Body, $ContentType, $ErrorAction)
    $CapturedBody = @{}
    foreach ($Entry in $Body.GetEnumerator()) { $CapturedBody[$Entry.Key] = $Entry.Value }
    $Script:TokenRequest = [pscustomobject]@{ Method = $Method; Uri = $Uri; Body = $CapturedBody; ContentType = $ContentType }
    [pscustomobject]@{ token_type = "Bearer"; access_token = "test-token" }
}
$TenantName = "contoso.onmicrosoft.com"
$ClientID = "00000000-0000-0000-0000-000000000001"
$ApplicationIDURI = "https://ConfigMgrService"
$Script:Password = "P@ssw0rd!"
$Credential = New-Object System.Management.Automation.PSCredential("svc-mdm@contoso.com", (ConvertTo-SecureString $Script:Password -AsPlainText -Force))
Get-AuthToken
if ($Script:TokenRequest.Uri -ne "https://login.microsoftonline.com/contoso.onmicrosoft.com/oauth2/token" -or
    $Script:TokenRequest.Method -ne "Post" -or
    $Script:TokenRequest.ContentType -ne "application/x-www-form-urlencoded" -or
    $Script:TokenRequest.Body.username -ne "svc-mdm@contoso.com" -or
    $Script:TokenRequest.Body.password -ne "P@ssw0rd!" -or
    $Script:AuthToken.Authorization -ne "Bearer test-token" -or
    $null -ne $Script:Password -or
    $null -ne $Script:Credential) {
    throw "Direct OAuth token acquisition failed"
}
if ($Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq "Install-AuthModule" }, $true)) {
    throw "Runtime authentication module installation is still present"
}
$EnablePinningNode = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq "Enable-AdminServiceCertificatePinning" }, $true)
$DisablePinningNode = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq "Disable-AdminServiceCertificatePinning" }, $true)
Invoke-Expression $EnablePinningNode.Extent.Text
Invoke-Expression $DisablePinningNode.Extent.Text
$PreviousCertificateCallback = [Net.ServicePointManager]::ServerCertificateValidationCallback
$Script:AdminServiceCertificateThumbprint = "A" * 40
try {
    Enable-AdminServiceCertificatePinning
    if ($null -eq [Net.ServicePointManager]::ServerCertificateValidationCallback) { throw "Certificate pinning callback was not enabled" }
}
finally {
    Disable-AdminServiceCertificatePinning
}
if (-not [object]::ReferenceEquals($PreviousCertificateCallback, [Net.ServicePointManager]::ServerCertificateValidationCallback)) {
    throw "Certificate validation callback was not restored"
}
$ScriptText = [IO.File]::ReadAllText($ScriptPath)
if ($ScriptText -match "(?i)\b(Install|Update)-Module\b" -or $ScriptText -match "ServerCertificateValidationCallbackEncoded") {
    throw "Unsafe runtime module installation or unconditional certificate bypass remains"
}
if (-not $ScriptText.Contains('throw "Unable to construct Microsoft.SMS.TSEnvironment object.')) {
    throw "Task-sequence environment initialization does not fail closed"
}
$FallbackNode = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq "Confirm-FallbackDriverPackage" }, $true)
if ($null -eq $FallbackNode) { throw "Fallback function not found" }
$PatternNode = $FallbackNode.Find({ param($Item) $Item -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $Item.Value -like "*Architecture*" -and $Item.Value -like "*x86*" }, $true)
if ("Driver Fallback Package - Windows 11 Arm64" -notmatch $PatternNode.Value -or $Matches.Architecture -ne "Arm64") { throw "Arm64 fallback parsing failed" }
Write-Output "Driver deployment regression checks passed."
