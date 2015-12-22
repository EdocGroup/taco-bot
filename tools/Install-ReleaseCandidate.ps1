param($Major = "7", $Minor="0", $Build="7", $Revision="MAX", $InstanceName, $Server="localhost", $Wipe="AnythingButYESRetainsData", $dbName, $SqlServer, $URL, $Alert)

#$Major  $Minor  $Build  $Revision
#-----   -----   -----   --------
#7       0       7        425

$SelgridServer = 'NIGHTLY'
$LiveDB = 'Helm_QABOT'

$PULL_REQUEST_BASE_DIR = "\\files.edoc.ca\dev\builds\helmconnect\releasecandidates"
$TEMP_DIR = "C:\temp"

switch -wildcard ($server)
{
	NIGHTLY {
		$akaName = $server
		$server = "ED-HELMSTG07"
		$URL = "nightly.helmdev.com"
		$InstanceName = "VM"
		$SqlServer = "ED-SQL2012STG01"
		$dbname = "HelmConnect_NIGHTLY" }		
	RC {
		$akaName = $server	
		$server = "ED-HELMRC01"
		$URL = "rc.helmdev.com"
		$InstanceName = "RC"
		$SqlServer = "ED-SQL2012"
		$dbname = "HelmConnect_RC" }
	MASTER {
		$akaName = $server	
		$server = "ED-HELMTEST01"
		$URL = "master.helmdev.com"
		$InstanceName = "Test"
		$SqlServer = "ED-SQL2012"
		$dbname = "HelmConnect_MASTER" }
	PREVIOUS {
		$akaName = $server
		$server = "ED-HELMSTG06"
		$URL = "previous.helmdev.com"
		$InstanceName = "VM"
		$SqlServer = "ED-SQL2012"
		$dbname = "HelmConnect_PREVIOUS" }
	RELEASE {
		$akaName = $server
		$server = "ED-HELMSTG01"
		$URL = "release.helmdev.com"
		$InstanceName = "Release"
		$SqlServer = "ED-SQL2012STG01"
		$dbname = "HelmConnect_RELEASE" }
	STABLE {
		$akaName = $server	
		$server = "ED-HELMSTG03"
		$URL = "stable.helmdev.com"
		$InstanceName = "Stable"
		$SqlServer = "ED-SQL2012"
		$dbname = "HelmConnect_STABLE" }		
	DEMO {
		$akaName = $server	
		$server = "ED-HELMDEMO01"
		$URL = "demo.helmdev.com"
		$InstanceName = "DEMO"
		$SqlServer = "ED-SQL2012STG01"
		$dbname = "HelmConnect_DEMO" }		
	TRIALS {
		$akaName = $Server
		$server = "ED-HELMTRIALS01"
		$URL = "trials.helmconnect.com"
		$InstanceName = "TRIALS"
		$SqlServer = "ED-SQL2012STG01"
		$dbname = "HelmConnect_TRIALS" }		
	ED-PR* {
		$akaName = $Server
		$litename = $Server.Replace("ED-","")
		$URL = "$litename.helmdev.com"
		$InstanceName = "VM"
		$SqlServer = "ED-SQL2012"
		$dbname = "HelmConnect_$litename" }				
	default {
		Write-Host Server info lookup failed to find '$Server' $server you must supply
		Write-Host a server $server
		Write-Host a URL $url
		Write-Host a InstanceName $InstanceName
		Write-Host a SqlServer $SqlServer 
		akaName = $Server }
		
}

		Write-Host server $server
		Write-Host URL $url
		Write-Host InstanceName $InstanceName
		Write-Host SqlServer $SqlServer 
		Write-Host dbName $dbname
		Write-Host akaName $akaName

if ($server -eq "localhost") {$server = ""}


$myDir = (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)
$manageHelm = (Join-Path $myDir "DeployScripts\Manage-Helm.ps1")
if ($URL -eq "") { $url = 'NIGHTLY.helmdev.com' }

# Find RC Version and path
function GetVersionNumber {
Param([String]$Major="7", [String]$Minor="0", [String]$Build="0", [String]$Revision="MAX")
if ($Build -eq "0") { Write-host "Please include -Build # to specify which release you want"; Exit }
#if ($Revision -eq 255) { $InstallRevision = "MAX" } 

$PULL_REQUEST_BASE_DIR = "\\files.edoc.ca\dev\builds\helmconnect\releasecandidates"

if ($Revision -eq "MAX")
{
$mV = ls $PULL_REQUEST_BASE_DIR `
	| where { $_ -match "^\d+\.\d+\.\d+\.\d+$" -or $_ -match "^\d+\.\d+\.\d+\.\d+\-RC$" }

$mV = $mV.ForEach{$_.Name.Replace("-RC","")}`
	| % { [System.Version]::Parse($_) } `
	| where { $_.Major -eq $Major -and $_.Minor -eq $Minor -and $_.Build -eq $Build} `
	| Measure-Object -Maximum
	Write-host {  Max Revision $_.Revision found  }
	return $mV
	}
	else
	{
		$mV = ls $PULL_REQUEST_BASE_DIR `
		| where { $_ -match "^\d+\.\d+\.\d+\.\d+$" -or $_ -match "^\d+\.\d+\.\d+\.\d+\-RC$" } 
		
		$mV = $mV.ForEach{$_.Name.Replace("-RC","")}`
		| % { [System.Version]::Parse($_) } `
		| where { $_.Major -eq $Major -and $_.Minor -eq $Minor -and $_.Build -eq $Build -and $_.Revision -eq $Revision }`
		| Measure-Object -Maximum
		if ($_.Revision -ne $null) { Write-host  Exact Revision $_.Revision found  }
		return $mV
	}
}

$maxVersion = GetVersionNumber -Major $Major -Minor $Minor -Build $Build -Revision $Revision

if ($maxVersion -eq $null)	{ Write-host could not find this version; Exit }

if (-not $maxVersion.Maximum) { Write-Host "Could not find any builds for pull request $PullRequestNumber";	Exit }
if ($SqlServer -eq $null) { Write-Host "You did not supply an InstanceName or there is no lookup predefined for '$Server': $server" Exit }
if ($InstanceName -eq $null) { Write-Host "You did not supply an InstanceName or there is no lookup predefined for '$Server': $server" Exit }

$version = $maxVersion.Maximum.ToString()
$msiDir = (Test-Path (Join-Path $PULL_REQUEST_BASE_DIR $version))
if ($msiDir) 
{ 
$msiDir = (Join-Path $PULL_REQUEST_BASE_DIR $version)
Write-Host "7z InstallPath is $msiDir"
 } 
else
{
$msiDir = (Test-Path (Join-Path $PULL_REQUEST_BASE_DIR $version-RC))
if ($msiDir) 
{ 
$msiDir = (Join-Path $PULL_REQUEST_BASE_DIR $version-RC)
Write-Host "7z InstallPath is $msiDir" 
} 
}

$msiFileName = (ls $msiDir)[0].Name
$originalMsiFilePath = (Join-Path $msiDir $msiFileName)

Write-Host "Found $originalMsiFilePath as filepath"

# Make sure there is a local temp dir
if (-not (Test-Path $TEMP_DIR)) {
	mkdir $TEMP_DIR
}
$tempMsiFilePath = (Join-Path $TEMP_DIR $msiFileName)

# Copy the msi to local temp dir
Write-Host "Copying to $tempMsiFilePath"
Copy-Item $originalMsiFilePath $tempMsiFilePath

# Install the 7z package
Write-Host "Installing $tempMsiFilePath"
& $manageHelm -Server $Server -Command install -InstallPackage $tempMsiFilePath


# Set instance to new version
Write-Host "Setting server '$Server' and instance '$InstanceName' to version '$version'"
$instanceConfig = (& $manageHelm -Command getconfig -Server $Server) | ConvertFrom-Json
if ($instanceConfig."$InstanceName" -eq $null) {
	Write-Error "$InstanceName not found in config"
	Exit
}
if ($instanceConfig."$InstanceName"."Version" -eq $null) {
	Write-Error "Corrupt config file. $InstanceName does not have a version property."
	Exit
}

$instanceConfig."$InstanceName"."Version" = $version
 
	if ($Alert)
	{	
	if ($instanceConfig."$InstanceName"."Alert" -eq $null) 
	{
	Write-Error "Config file $InstanceName does not have an Alert property, continuing without setting"
	}
	else
	{
	if ($Alert -Eq 'Version')
	{
	$Alert = $version
	}
	Write-Host "Setting Helm Alert to ${Alert} ..."
	$instanceConfig."$InstanceName"."Alert" = $Alert
	}
	}
	
	$instanceConfigText = (ConvertTo-Json $instanceConfig -Depth 100)
& $manageHelm -Command config -Server $Server -ConfigText $instanceConfigText

##stop server
Write-Host "Stopping instance '$InstanceName' on '$Server'"
& $manageHelm -Command stop -Server $Server -InstanceName $InstanceName


pop-location 

##delete database
if ($Build -eq "7" -Or $Wipe -eq "YES")
{
try
{
if ($Build -eq "7") { Write-Host "This is release 7. Database is being WIPED" }
if ($dbName -eq $null) { Write-Host "Please specify the dbname or add it to the lookup for '$Server': $Server"; Exit }
if ($Wipe -ne "AnythingButYESRetainsData" -And $Wipe -ne "YES")
 { 
 Write-Host "$Wipe variable was modified but not set to YES, choosing NOT to wipe. please change $Wipe to all caps YES to wipe next time"
 Exit
 }

& Invoke-Sqlcmd -Query "declare @kill varchar(8000) = ''; select @kill=@kill+'kill '+convert(varchar(5),spid) + ';' from master..sysprocesses where dbid=db_id('$dbName');exec (@kill);" -ServerInstance $SqlServer

#ready db for delete
& Invoke-Sqlcmd -Query "ALTER DATABASE $dbName SET SINGLE_USER WITH ROLLBACK IMMEDIATE" -ServerInstance $SqlServer

#drop db
& Invoke-Sqlcmd -Query "DROP DATABASE $dbName" -ServerInstance $SqlServer
& Invoke-Sqlcmd -Query "Update Status set LastServerAction='Kill DB' Where MachineName = '$Server' " -ServerInstance $SqlServer -Database "$LIVEDB"
}
catch { Write-Host "caught exception deleting $server 's db " + $dbname}

try{
#create db
& Invoke-Sqlcmd -Query "CREATE DATABASE $dbName" -ServerInstance $SqlServer
& Invoke-Sqlcmd -Query "Update Status set LastServerAction='Create DB' Where MachineName = '$Server' " -ServerInstance $SqlServer -Database "$LIVEDB"
}
catch { Write-Host "caught exception deleting $server 's db " + $dbname}
}



Write-Host "Starting instance '$InstanceName' on '$Server'"
& $manageHelm -Command start -Server $Server -InstanceName $InstanceName

###
##update selgrid

Write-Host LXC is $LastExitCode 
& (Join-Path $myDir 'Wait-ServerStarted.ps1') -Url "http://admin.$url" -MaxTries 35 -Verbose
Write-Host LXC is $LastExitCode 

if ($LastExitCode -Ne 0)
	{
	
		Write-Host "LXC was not 0... will restart server and try once more"
	
			Write-Host "Stopping instance '$InstanceName' on '$Server'"
			& $manageHelm -Command stop -Server $Server -InstanceName $InstanceName
			
			#catch { Write-Host "caught error in stopping $server " + $_ }
		#	try {
			Write-Host "Starting instance '$InstanceName' on '$Server' 2nd time"
			& $manageHelm -Command start -Server $Server -InstanceName $InstanceName 
		# }
		#	catch {Write-Host "caught error in starting server " + $_}

	#	try{
		& (Join-Path $myDir 'Wait-ServerStarted.ps1') -Url "http://admin.$url" -MaxTries 25 -Verbose
			
		#	}
		#catch {
			Write-Host $LastExitCode is LXC
		#	}

	}

	if ($LastExitCode -Ne 0)
	{
		Write-Host "LXC was not 0...error starting server db.. pulling event logs.."



	$TenMinAgo = (Get-Date) - (New-TimeSpan -Minute 10)
	$logs = Get-EventLog Application -Source HelmConnect -After $TenMinAgo -EntryType Error
	if ($logs)
		{
		$logs
		Write-Host "Found FATAL HelmCONNECT ERRORS that blocked the server from starting in the past 10 minutes in the event LOG!!!"
		$logs.Message
		Write-Host "Found FATAL HelmCONNECT ERRORS that blocked the server from starting in the past 10 minutes in the event LOG!!!"
		$logs.Message
		Write-Host "Found FATAL HelmCONNECT ERRORS that blocked the server from starting in the past 10 minutes in the event LOG!!!"
		$logs.Message
		}
		& Invoke-Sqlcmd -Query "Update Status set LastServerAction='Failed2Start', updating = 0 Where MachineName = '$akaName' " -ServerInstance $SqlServer -Database "$LIVEDB"
		Exit $LastExitCode
	}


if ($LastExitCode -Eq 0)
	{
		Write-Host "LXC was 0.. server http://admin.$url is accepting api requests"

		$TenMinAgo = (Get-Date) - (New-TimeSpan -Minute 10)
		$logs = Get-EventLog Application -Source HelmConnect -After $TenMinAgo -EntryType Error
		if ($logs)
			{
				$logs
				Write-Host "Found HelmCONNECT ERRORS (that did NOT block the server from starting) in the past 10 minutes in the event LOG!!!"
				$logs.Message
				& Invoke-Sqlcmd -Query "Update Status set LastServerAction='Started W/Errors' Where MachineName = '$akaName' " -ServerInstance $SqlServer -Database "$LIVEDB"
			}
			else
			{
				& Invoke-Sqlcmd -Query "Update Status set LastServerAction='Server up' Where MachineName = '$akaName' " -ServerInstance $SqlServer -Database "$LIVEDB"
			}
		#& cmd.exe /c "ping 0.0.0.0 -w 1000 -n 3 -l 0"

	}
	
