#region Functions
function Display-ToastNotification() {

    # Load the notification into the required format
    $ToastXML = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
    $ToastXML.LoadXml($Toast.OuterXml)
        
    # Display the toast notification
    try {
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($App).Show($ToastXml)
    }
    catch { 
        Write-Output -Message 'Something went wrong when displaying the toast notification' -Level Warn
        Write-Output -Message 'Make sure the script is running as the logged on user' -Level Warn     
    }
}
#endregion Functions

#region Declarations
# Setting image variables
$LogoImageUri ='https://cloudway.no/wp-content/uploads/2020/03/CWNotificationsIcon.png'
$HeroImageUri = 'https://cloudway.no/wp-content/uploads/2020/03/CWNotificationsHero.png'
$LogoImage = "$env:TEMP\ToastLogoImage.png"
$HeroImage = "$env:TEMP\ToastHeroImage.png"
$UpdatedAppID = 'id2'
$OrgAppVersion = 'TeamViewer 15.1.3937'
$NewAppVersion = ''

#Fetching images from uri
Invoke-WebRequest -Uri $LogoImageUri -OutFile $LogoImage
Invoke-WebRequest -Uri $HeroImageUri -OutFile $HeroImage

#Defining the Toast notification settings
$XML = [xml] @"
<?xml version='1.0' encoding='utf-8'?>
<Configuration>
	<Feature Name='Toast' Enabled='True' /> <!-- Enables or disables the entire toast notification -->
    <Option Name='UsePowershellApp' Enabled='True' />	<!-- The app in Windows doing the action notification -->
	<Option Name='ActionButton' Enabled='True' Value='Update now' />	<!-- Enables or disables the action button. Value is equal to the name displayed on the button -->
	<Option Name='DismissButton' Enabled='True' Value='Dismiss' />	<!-- Enables or disables the dismiss button. Value is equal to the name displayed on the button -->
    <Option Name='SnoozeButton' Enabled='True' Value='Snooze' /> <!-- Enabling this option will always enable action button and dismiss button -->
    <Option Name='Scenario' Type='reminder' />	<!-- Possible values are: reminder | short | long -->
	<Option Name='Action' Value='companyportal:Applicationid=id2' />	<!-- Action taken when using the Action button. Can be any protocol in Windows -->
    <Text Name='AttributionText'>CloudWay</Text>
	<Text Name='HeaderText'>Application Update needed</Text>
	<Text Name='TitleText'>TeamViewer 15.1.3937 needs and update!</Text>
	<Text Name='BodyText1'>For security and stability reasons, we kindly ask you to update to  as soon as possible.</Text>
	<Text Name='BodyText2'>Updating your 3rd party apps on a regular basis ensures a secure Windows. Thank you in advance.</Text>
	<Text Name='SnoozeText'>Click snooze to be reminded again in:</Text>
	<Text Name='DeadlineText'>Your deadline is:</Text>
	<Text Name='GreetAfternoonText'>Good afternoon</Text>
	<Text Name='GreetEveningText'>Good evening</Text>
	<Text Name='MinutesText'>Minutes</Text>
	<Text Name='HourText'>Hour</Text>
	<Text Name='HoursText'>Hours</Text>
	<Text Name='ComputerUptimeText'>Computer uptime:</Text>
	<Text Name='ComputerUptimeDaysText'>days</Text>
</Configuration>
"@

# Load xml configuration into variables
try {
    # Load Toast Notification features 
    $ToastEnabled = $XML.Configuration.Feature | Where-Object {$_.Name -like 'Toast'} | Select-Object -ExpandProperty 'Enabled'
     
    # Load Toast Notification options   
    $PSAppStatus = $_.Configuration.Option | Where-Object {$_.Name -like 'UsePowershellApp'} | Select-Object -ExpandProperty 'Enabled'
    $Scenario = $_.Configuration.Option | Where-Object {$_.Name -like 'Scenario'} | Select-Object -ExpandProperty 'Type'
    $Action = $_.Configuration.Option | Where-Object {$_.Name -like 'Action'} | Select-Object -ExpandProperty 'Value'
        
    # Load Toast Notification buttons
    $ActionButtonEnabled = $_.Configuration.Option | Where-Object {$_.Name -like 'ActionButton'} | Select-Object -ExpandProperty 'Enabled'
    $ActionButtonContent = $_.Configuration.Option | Where-Object {$_.Name -like 'ActionButton'} | Select-Object -ExpandProperty 'Value'
    $DismissButtonEnabled = $_.Configuration.Option | Where-Object {$_.Name -like 'DismissButton'} | Select-Object -ExpandProperty 'Enabled'
    $DismissButtonContent = $_.Configuration.Option | Where-Object {$_.Name -like 'DismissButton'} | Select-Object -ExpandProperty 'Value'
    $SnoozeButtonEnabled = $_.Configuration.Option | Where-Object {$_.Name -like 'SnoozeButton'} | Select-Object -ExpandProperty 'Enabled'
    $SnoozeButtonContent = $_.Configuration.Option | Where-Object {$_.Name -like 'SnoozeButton'} | Select-Object -ExpandProperty 'Value'

    # Load Toast Notification text
    $AttributionText = $_.Configuration.Text| Where-Object {$_.Name -like 'AttributionText'} | Select-Object -ExpandProperty '#text'
    $HeaderText = $_.Configuration.Text | Where-Object {$_.Name -like 'HeaderText'} | Select-Object -ExpandProperty '#text'
    $TitleText = $_.Configuration.Text | Where-Object {$_.Name -like 'TitleText'} | Select-Object -ExpandProperty '#text'
    $BodyText1 = $_.Configuration.Text | Where-Object {$_.Name -like 'BodyText1'} | Select-Object -ExpandProperty '#text'
    $BodyText2 = $_.Configuration.Text | Where-Object {$_.Name -like 'BodyText2'} | Select-Object -ExpandProperty '#text'
    
    # New text options
    $SnoozeText = $_.Configuration.Text | Where-Object {$_.Name -like 'SnoozeText'} | Select-Object -ExpandProperty '#text'
	$DeadlineText = $_.Configuration.Text | Where-Object {$_.Name -like 'DeadlineText'} | Select-Object -ExpandProperty '#text'
	$HourText = $_.Configuration.Text | Where-Object {$_.Name -like 'HourText'} | Select-Object -ExpandProperty '#text'
    $HoursText = $_.Configuration.Text | Where-Object {$_.Name -like 'HoursText'} | Select-Object -ExpandProperty '#text'
	 
    Write-Output -Message 'Successfully loaded xml content' 
}
catch {
    Write-output -Message 'Xml content was not loaded properly'
    Exit 1
}
#endregion Declarations

#region Formatting
# Check for required entries in registry for when using Powershell as application for the toast
if ($PSAppStatus -eq 'True') {

    # Register the AppID in the registry for use with the Action Center, if required
    $RegPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings'
    $App =  '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    
    # Creating registry entries if they don't exists
    if (-NOT(Test-Path -Path "$RegPath\$App")) {
        New-Item -Path "$RegPath\$App" -Force
        New-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD'
    }
    
    # Make sure the app used with the action center is enabled
    if ((Get-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -ErrorAction SilentlyContinue).ShowInActionCenter -ne '1') {
        New-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD' -Force
    }
}

# Formatting the toast notification XML
# Create the default toast notification XML with action button and dismiss button
if (($ActionButtonEnabled-eq 'True') -AND ($DismissButtonEnabled -eq 'True')) {
    Write-Output -Message 'Creating the xml for displaying both action button and dismiss button'
[xml]$Toast = @"
<toast scenario='$Scenario'>
    <visual>
    <binding template='ToastGeneric'>
        <image placement='hero' src='$HeroImage'/>
        <image id='1' placement='appLogoOverride' hint-crop='circle' src='$LogoImage'/>
        <text placement='attribution'>$AttributionText</text>
        <text>$HeaderText</text>
        <group>
            <subgroup>
                <text hint-style='title' hint-wrap='true' >$TitleText</text>
            </subgroup>
        </group>
        <group>
            <subgroup>     
                <text hint-style='body' hint-wrap='true' >$BodyText1</text>
            </subgroup>
        </group>
        <group>
            <subgroup>     
                <text hint-style='body' hint-wrap='true' >$BodyText2</text>
            </subgroup>
        </group>
    </binding>
    </visual>
    <actions>
        <action activationType='protocol' arguments='$Action' content='$ActionButtonContent' />
        <action activationType='system' arguments='dismiss' content='$DismissButtonContent'/>
    </actions>
</toast>
'@
}
# Snooze button - this option will always enable both action button and dismiss button regardless of config settings
if ($SnoozeButtonEnabled -eq 'True') {
    Write-Output -Message 'Creating the xml for snooze button'
[xml]$Toast = @'
<toast scenario='$Scenario'>
    <visual>
    <binding template='ToastGeneric'>
        <image placement='hero' src='$HeroImage'/>
        <image id='1' placement='appLogoOverride' hint-crop='circle' src='$LogoImage'/>
        <text placement='attribution'>$AttributionText</text>
        <text>$HeaderText</text>
        <group>
            <subgroup>
                <text hint-style='title' hint-wrap='true' >$TitleText</text>
            </subgroup>
        </group>
        <group>
            <subgroup>     
                <text hint-style='body' hint-wrap='true' >$BodyText1</text>
            </subgroup>
        </group>
        <group>
            <subgroup>     
                <text hint-style='body' hint-wrap='true' >$BodyText2</text>
            </subgroup>
        </group>
    </binding>
    </visual>
    <actions>
        <input id='snoozeTime' type='selection' title='$SnoozeButtonText' defaultInput='15'>
            <selection id='15' content='15 $MinutesText'/>
            <selection id='30' content='30 $MinutesText'/>
            <selection id='60' content='1 $HourText'/>
            <selection id='240' content='4 $HoursText'/>
            <selection id='480' content='8 $HoursText'/>
        </input>
        <action activationType='protocol' arguments='$Action' content='$ActionButtonContent' />
        <action activationType='system' arguments='snooze' hint-inputId='snoozeTime' content='$SnoozeButtonContent'/>
        <action activationType='system' arguments='dismiss' content='$DismissButtonContent'/>
    </actions>
</toast>
"@
}
#endregion Formatting

#Send the notification
Display-ToastNotification
Exit 0

