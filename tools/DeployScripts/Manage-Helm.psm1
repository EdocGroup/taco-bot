function Manage-Helm {
    param(
            [string]$Command, 
            [string]$Server, 
            [string]$ConfigPath, 
            [string]$ConfigText, 
            [string]$MsiPath, 
            [string]$MsiArchive, 
            [string]$InstallPackage,
            [string]$InstanceName, 
            [string]$CertPath, 
            [string]$Port, 
            [string]$CertPassword,
            [string]$SqlISOPath,
	        [string]$Source,
	        [string]$Destination,
	        [System.Management.Automation.PSCredential] $Credential = $null,
            $Session = $null,
            [switch]$NoKillSession,
	        [string]$SQLSYSADMINACCOUNT,
	        [string]$INSTALLSHAREDDIR,
	        [string]$INSTALLSHAREDWOWDIR,
	        [string]$INSTANCEDIR)

    try {
 
        ###############################################################################
        # Globals
        ###############################################################################
        $7z = Join-Path (Get-ItemProperty "HKCU:\Software\7-Zip").Path "7z.exe"

        ###############################################################################
        # Helper function for transferring file via powershell remoting: Handles arbitrarily large files!
        ###############################################################################
        function Send-File {
			param($Source, $Destination, $Session)

			if ([string]::IsNullOrWhitespace($Source)) {
		        Write-InvalidUsage "Source parameter required"
	        }
			if ([string]::IsNullOrWhitespace($Destination)) {
		        Write-InvalidUsage "Destination parameter required"
	        }
			
			$openMode = [System.IO.FileMode]::Open
			$readAccess = [System.IO.FileAccess]::Read

			## Get the source file, and then get its content
			$sourcePath = (Resolve-Path $source).Path
			$fs = New-Object IO.FileStream($sourcePath, $openMode, $readAccess)

			$converter = (1024*1024)
			$fileLengthMB = $fs.Length/$converter
			$maxLength = 33554432 #32MB in bytes
			$numBytesRead = 0
			$numBytesToRead = $fs.Length
			
			
			#we need to check if this destination file exists. If it does, we're going to quit and prompt for a rename.
			#we don't want to try and overwrite the file that exists because we can't rollback if this send-file fails	
			$checkFileScript = {
			param($destination)
				$checkfile = test-path $destination
				if($checkfile) {
					Write-Host "Destination File: "$destination" already exists. Please rename destination file, or remove existing file"
					return $false
				}
				return $true		
			}
			
			if ($session) { 
				$result = Invoke-Command -Session $session $checkFileScript -ArgumentList $Destination
			} else {
				$result = Invoke-Command $checkFileScript -ArgumentList $Destination
			}
			if(!$result) {
				return;
			}
			
			
			
			while ($numBytesToRead -gt 0) {
				$arraylength = [Math]::Min($numBytesToRead,$maxLength)
				$sourceBytes = New-Object byte[] $arraylength
				$n = $fs.Read($sourceBytes, 0,$arraylength)
				if($n -eq 0) {
					return
					}
				$numBytesRead = $numBytesRead+$n
				$numBytesToRead =  $numBytesToRead - $n
				write-host "Source slice (MB): "($numBytesRead/$converter)"/"$fileLengthMB	
						

				$streamChunks = @()

				## Now break it into chunks to stream
				Write-Progress -Activity "Sending $Source" -Status "Preparing file"
				$streamSize = 1MB
				for($position = 0; $position -lt $sourceBytes.Length; $position += $streamSize) {
					$remaining = $sourceBytes.Length - $position
					$remaining = [Math]::Min($remaining, $streamSize)

					$nextChunk = New-Object byte[] $remaining
					[Array]::Copy($sourcebytes, $position, $nextChunk, 0, $remaining)
					$streamChunks += ,$nextChunk
				}
			
				#Remote script to be run on target side.
				$remoteScript = {
					param($destination, $length, $numBytesRead)
							
					## Convert the destination path to a full filesytem path (to support
					## relative paths)
					$Destination = $executionContext.SessionState.`
						Path.GetUnresolvedProviderPathFromPSPath($Destination)

					## Create a new array to hold the file content
					$destBytes = New-Object byte[] $length
					$position = 0

					## Go through the input, and fill in the new array of file content
					foreach($chunk in $input)
					{
						Write-Progress -Activity "Writing $Destination" `
							-Status "Sending Slice" `
							-PercentComplete ($position / $length * 100)

						[GC]::Collect()
						[Array]::Copy($chunk, 0, $destBytes, $position, $chunk.Length)
						$position += $chunk.Length
					}
					#we're using this so that we can append (or create if non-existent) to our destination file. Third parameter "$true" means to append.
					Add-Type -AssemblyName Microsoft.VisualBasic
					[Microsoft.VisualBasic.FileIO.FileSystem]::WriteAllBytes($destination, $destBytes, $true)				
					[GC]::Collect()
				}
				if ($session) { 
					$streamChunks | Invoke-Command -Session $session $remoteScript -ArgumentList $destination,$sourceBytes.Length, $numBytesRead
				} else {
					$streamChunks | Invoke-Command $remoteScript -ArgumentList $destination,$sourceBytes.Length, $numBytesToRead
				}
			}
		}

        ###############################################################################
        # Functions that implement commands
        ###############################################################################
        function Get-Status {
	        $instanceInfos = Get-InstanceStatuses
	        $versions = Get-AvailableHelmVersions
	        $hasConfig = $false
            
	        # warn about old services
	        foreach ($info in $instanceInfos.Values) {
		        if ($info["FullServiceName"].StartsWith("HelmNext_")) {
			        Write-Host "WARNING - The windows service $($info.FullServiceName) is using the old naming scheme. You should delete it."
			        Write-Host "          (It will automatically be recreated with the correct name when you start it again)"
			        Write-Host "  example:"
			        Write-Host "    Manage-Helm.ps1 -Server <server> -Command stop -InstanceName $($info.FullServiceName.Split('_', 2)[1])"
			        Write-Host "    Manage-Helm.ps1 -Server <server> -Command delete -InstanceName $($info.FullServiceName.Split('_', 2)[1])"
			        Write-Host ""
		        }
	        }

	        Write-Host "Instances:"
	        Write-Host " ------------------------------------------------------------------------------"
	        Write-Host "| Name                    | Status          | Config Version | Service Version |"
	        Write-Host "|------------------------------------------------------------------------------|"
	        foreach ($info in $instanceInfos.Values) {
		        if (-not $info["FullServiceName"].StartsWith("HelmNext_")) {
			        if (-not ([string]::IsNullOrWhitespace($info['ConfigVersion']))) {
				        $hasConfig = $true
			        }
			        Write-Host "| $($info['Name'].PadRight(24, ' ').Substring(0,24))| $($info['Status'].PadRight(16, ' ').Substring(0,16))| $($info['ConfigVersion'].PadRight(15, ' ').Substring(0,15))| $($info['ServiceVersion'].PadRight(15, ' ').Substring(0,15)) |"
		        }
	        }
	        Write-Host " ------------------------------------------------------------------------------"
	        Write-Host ""
			

	        if ($versions -eq $null) {
		        Write-Host "HELM IS NOT INSTALLED"
	        } else {
		        Write-Host "Versions available:"
		        foreach ($versionDir in $versions) {
			        $version = [System.IO.Path]::GetFileName($versionDir)
			        Write-Host "  $version"
		        }
				Write-Host "Currently installed version: " $($info['ConfigVersion'])				
	        }
	
	        if ($hasConfig -eq $false) {
		        Write-Host "NO CONFIG FILE FOUND"
			 }
			 return $info['ConfigVersion'];
        }

        function Get-ConfigText {
            $block = {
		        $programDataPath = [environment]::getfolderpath("commonapplicationdata")
		        $helmConnectPath = (Join-Path $programDataPath "\edoc\HelmConnect")
		        $instanceFilePath = (Join-Path $helmConnectPath "instances.json")
		        if ((Test-Path $instanceFilePath)) {
			        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
			        $jsonText = [System.IO.File]::ReadAllText((Resolve-Path $instanceFilePath))
			        return $jsonText
		        } else {
			        return $null
		        }
	        }
	        if ($session) {Invoke-Command -Session $session -ScriptBlock $block} else {Invoke-Command -ScriptBlock $block}
        }

		function Get-InstallDir{
		    
		}

        function Write-ConfigFile {
	        if (-not (Get-HelmInstallExists)) {
		        Write-Error "Helm is not installed"
		        Throw "exit"
	        }
            Write-Host "Write-ConfigFile"
	        $remoteBlock = {
		        param($Text)
				$basePath = (Get-ItemProperty -Path "HKLM:\Software\Edoc\HelmConnect").InstallDir
		        if ([string]::IsNullOrWhitespace($basePath)) {
                    Write-Host "Couldn't find value for InstallDir in key HKLM:\Software\Edoc\HelmConnect"
			        return $null
		        }
		        if ([System.IO.Directory]::GetDirectories((Join-Path $basePath "versions")).length -ge 1){
					
			        $dir = [Environment]::GetFolderPath("commonapplicationdata")
			        $dir = (Join-Path $dir "Edoc")
			        if (-not (Test-Path $dir)) {
				        [void](New-Item -ItemType Directory -Path $dir)
			        }
			        $dir = (Join-Path $dir "HelmConnect")
			        if (-not (Test-Path $dir)) {
				        [void](New-Item -ItemType Directory -Path $dir)
			        }
			        $path = (Join-Path $dir "instances.json")
                    Write-Host "Writing config to $path"
			        [void]([System.IO.File]::WriteAllText($path, $Text))
		        } else {
			        Write-Error "HelmConnect is not installed on $Server"
		        }
		
	        }

	        if ([string]::IsNullOrWhitespace($ConfigPath) -and [string]::IsNullOrWhitespace($ConfigText)) {
		        Write-InvalidUsage "ConfigPath or ConfigText parameter required"
	        } elseif ([string]::IsNullOrWhitespace($ConfigText)) {
		        if (Test-Path $ConfigPath) {
			        $ConfigText = [System.IO.File]::ReadAllText((Resolve-Path $ConfigPath))
		        } else {
			        Write-Error "Could not find $ConfigPath"
		        }
	        }
            Write-Host "Copying config file..."
            if ($session) { 
                Invoke-Command -Session $session -ScriptBlock $remoteBlock -Args $ConfigText
            } else {
                Invoke-Command  -ScriptBlock $remoteBlock -Args $ConfigText
            }
        }

		# function Setup-NodeUpdatePackage{
		# 	$block = {
		# 		param($version, $tempFilePath, $fileName)
		# 			$basePathKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64).OpenSubKey("Software\Edoc\HelmConnect")
		# 			$installDir = $basePathKey.GetValue("InstallDir").ToString()
		# 			$versionPath = (Join-Path (Join-Path $installDir "versions") $version)
		# 			if ((Test-Path $versionPath) -and (Test-Path $tempFilePath)){
		# 				$tempFileName = Split-Path $tempFilePath -leaf -resolve
		# 				$finalDir = "$versionPath\Modules\Helm\WebContent\Public\Update"
		# 				Move-Item $tempFilePath $finalDir
		# 				Rename-Item -Path (Join-Path $finalDir $tempFileName)  -NewName $fileName
		# 			}
		# 			else{
		# 				Write-Error "Could not find a matching version of the MSI and the installed versions."
						
		# 			}
		# 	}
		# 	$bitness = [Regex]::Match($MsiPath, "(x)([0-9][0-9])").Value
		# 	$version = [Regex]::Match($MsiPath, ".*_(\d+\.\d+\.\d+\.\d+)\.7z$").Groups[1].Value
		# 	$fileName = "update-${bitness}_${version}.zip"
		# 	$sourceTempDir = "C:\Temp\$([Guid]::NewGuid())"
		# 	$sourceFilePath = Join-Path $sourceTempDir "update-${bitness}_${version}.zip" 
		# 	$destTempDir = "C:\Temp\$([Guid]::NewGuid()).zip"
		# 	Zip-File $MsiPath $sourceFilePath

		# 	if ($session) { 
		# 		Send-File $sourceFilePath $destTempDir $session 
		# 	}

		# 	if ($session) { 
		# 		Invoke-Command -Session $session -ScriptBlock $block -ArgumentList $version,$destTempDir,$fileName
		# 	} else {
		# 		Invoke-Command -ScriptBlock $block -ArgumentList $version,$destTempDir,$fileName
		# 	}

		# 	#Remove-Item $sourceFilePath
		# }

        function Install-Helm {
        	if ($MsiPath -or $MsiArchive) {
        		Write-InvalidUsage "MsiPath and MsiArchive are no longer valid. User InstallerPackage instead (it should be a 7z file)."
        	}

	        if ([string]::IsNullOrWhitespace($InstallPackage)) {
		        Write-InvalidUsage "InstallPackage parameter required (should point to a 7z file)"
	        }

	        if (-not $InstallPackage.EndsWith(".7z")) {
		        Write-Host "WARNING: The file you chose does not have 7z extension. Did you pick the wrong file?"
	        }

	        $makeTempDir = {
		        param($dir)
		        [void](New-Item $dir -Type directory)
	        }

	        $killTempDir = {
		        param($dir)
		        [void](Remove-Item -Recurse -Force $dir)
	        }

	        $tempDir = "C:\Temp\$([Guid]::NewGuid())"
            
	        # Create a folder to put the zip file on the target server
            if ($session) {
                Invoke-Command -Session $session -ScriptBlock $makeTempDir -ArgumentList $tempDir 
            } else {
                Invoke-Command  -ScriptBlock $makeTempDir -ArgumentList $tempDir 
            }
	        try {
		        # Copy helm package to target server
		        $packageName = Split-Path $InstallPackage -leaf
		        $packageDestination = (Join-Path $tempDir $packageName)
		        Send-File $InstallPackage $packageDestination $session

                $installBlock = {
                	param($PackageDestination, $TempDir)

                    # Get the install directory from registry
                    $oldErrorAction = $ErrorActionPreference
                    $ErrorActionPreference = 'silentlycontinue'
                    $installDir = $null
                    try {
                        $installDir = (Get-ItemProperty -Path "HKLM:\Software\Edoc\HelmConnect").InstallDir
                    } catch {
                        $installDir = $null                        
                    } finally {
                        $ErrorActionPreference = $oldErrorAction
                    }

                    # If install dir is not already in the registry then put it there now
                    if ($installDir -eq $null) {
                        Write-Host ">>> InstallDir does not exist, creating it now"
                        $installDir = Join-Path $env:ProgramFiles "HelmConnect\"
                        New-Item -Path "HKLM:\Software\Edoc\HelmConnect" -Force
                        Set-ItemProperty -Path "HKLM:\Software\Edoc\HelmConnect" -Name "InstallDir" -Value $installDir
                        $newValue = (Get-ItemProperty -Path "HKLM:\Software\Edoc\HelmConnect").InstallDir
                        Write-Host "InstallDir set to '$newValue'"
                    } else {
                        Write-Host ">>> InstallDir already exists"
                    }

                    # If the versions directory does not exist then create it now
                    $versionsDir = Join-Path $installDir "versions"
                    if (-not (Test-Path $versionsDir)) {
                        New-Item -ItemType Directory -Path $versionsDir
                    }

                    # If this specific version is already installed then try to delete it so we can replace
                    $thisVersion = [Regex]::Match($PackageDestination, ".*_(\d+\.\d+\.\d+\.\d+)\.7z$").Groups[1].Value
                    $thisVersionDir = Join-Path $versionsDir $thisVersion
                    if (Test-Path $thisVersionDir) {
					    Remove-Item $thisVersionDir -Recurse -Force
                    } 
                	# Extract the package directly to versions dir

			# First try with c:\Program Files\7-Zip\ 
			# If not found then resort to asking registry

			$7z = (Join-Path "C:\Program Files\7-Zip" 7z.exe)
			if (-not (Test-Path $7z)) { $7z = Join-Path (Get-ItemProperty "HKCU:\Software\7-Zip").Path "7z.exe" }
			& $7z x $PackageDestination "-o$versionsDir" | out-null

                    # Copy the install package into itself for node propogation
                    $newPackageDestination = Join-Path $thisVersionDir "Modules\Helm\WebContent\Public\Installation"
                    Move-Item $PackageDestination $newPackageDestination
                } 

                if ($session){
                    Invoke-Command -Session $session -ScriptBlock $installBlock -ArgumentList $packageDestination,$tempDir
                } else {
                    Invoke-Command -ScriptBlock $installBlock -ArgumentList $packageDestination,$tempDir
                }

	        } catch {
                Write-Output $_
            }
        }

        function Uninstall-Helm {
            Remove-AllTracesOfHelmFromThisComputer
        }

        function Start-Service {
	        if (-not (Get-HelmInstallExists)) {
		        Write-Error "Helm is not installed"
		        Throw "exit"
	        }
	        if ([string]::IsNullOrWhitespace($InstanceName)) {
		        Write-InvalidUsage "InstanceName parameter is required"
	        }

	        $remoteBlock = {
		        param($serviceName, $configVersion)

                if (-not (Test-Path "HKLM:\Software\Edoc\HelmConnect")) {
                    Write-Error "The reg key 'HKLM:\Software\Edoc\HelmConnect' was not found"
                    return $null
                }

                $basePath = (Get-ItemProperty -Path "HKLM:\Software\Edoc\HelmConnect").InstallDir

		        $exePath = [System.IO.Path]::Combine($basePath, "versions", $configVersion, "TurboShell.WinServ\bin\Release\TurboShell.WinServ.exe")

		        [void][System.Reflection.Assembly]::LoadWithPartialName("System.ServiceProcess")
		        $serviceController = New-Object System.ServiceProcess.ServiceController($serviceName)
		        if ($serviceController.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
			        Write-Error "Service already running"
		        } elseif ($serviceController.Status -eq $null) {
			        # the service did not exist, so create it
			        [void](& cmd /C "sc create $serviceName binPath= ""$exePath"" start= auto")
			        $serviceController.Start()
		        } else {
			        # service already exists, so check if it is the right version
			        $actualVersion = $null
			        try {
				        $key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64).OpenSubKey("SYSTEM\CurrentControlSet\Services\$serviceName")
				        $value = $key.GetValue("ImagePath").ToString()
				        $key.Close()
				        if ($value.StartsWith('"')) {
					        $value = [System.Text.RegularExpressions.Regex]::Match($value, '"([^"]+)"').Groups[1].Value
				        }
				        $actualExePath = [System.Environment]::ExpandEnvironmentVariables($value)
				        $actualVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($actualExePath).FileVersion.ToString()
			        } catch { }

			        # if the version is wrong then change it
			        if ($actualVersion -ne $configVersion) {
				        [void](& cmd /C "sc config $serviceName binPath= ""$exePath""")
			        }

			        $serviceController.Start()
		        }

		        $serviceController.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, [Timespan]::FromSeconds(10))
	        }
            $statuses = @()
	        $statuses = Get-InstanceStatuses
	        if ((-not $statuses[$InstanceName]) -or (-not $statuses[$InstanceName]["ConfigVersion"])) {
		        Write-Error "The instance '$InstanceName' does not exist in the config file."
	        } else {
		        $serviceName = $statuses[$InstanceName]["FullServiceName"]
		        $configVersion = $statuses[$InstanceName]["ConfigVersion"]

		        $availableVersions = Get-AvailableHelmVersions
		        if (($availableVersions | ? { [System.IO.Path]::GetFileName($_) -eq $configVersion }) -eq $null) {
			        Write-Error "Cannot start instance because version '$configVersion' is not installed."
			        return
		        }
                Write-Host "Starting Helm Connect service..."
                if ($session) {
		            Invoke-Command -Session $session -ScriptBlock $remoteBlock -ArgumentList $serviceName,$configVersion
                } else {
    		        Invoke-Command -ScriptBlock $remoteBlock -ArgumentList $serviceName,$configVersion
                }
                Write-Host "Done! Helm Connect started!"
	        }
        }

        function Stop-MyService {
	        if ([string]::IsNullOrWhitespace($InstanceName)) {
		        Write-InvalidUsage "InstanceName parameter is required"
	        }

	        $remoteBlock = {
		        param($serviceName)

		        [void][System.Reflection.Assembly]::LoadWithPartialName("System.ServiceProcess")
		        $serviceController = New-Object System.ServiceProcess.ServiceController($serviceName)
		        if ($serviceController.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
			        $serviceController.Stop()
		        } elseif ($serviceController.Status -eq $null) {
			        Write-Host "Service does not exist"
		        } else {
			        #Write-Host "Service was not running"
		        }

		        $serviceController.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [Timespan]::FromSeconds(10))
	        }

	        $statuses = Get-InstanceStatuses
	        if (-not $statuses[$InstanceName]) {
		        Write-Host "The instance '$InstanceName' does not exist."
	        } else {
		        $serviceName = $statuses[$InstanceName]["FullServiceName"]
                if ($session) {
		            Invoke-Command -Session $session -ScriptBlock $remoteBlock -ArgumentList $serviceName
                } else {
		            Invoke-Command -ScriptBlock $remoteBlock -ArgumentList $serviceName
                }
	        }
        }

        function Delete-Service {
	        $remoteBlock = {
		        param($serviceName)

		        [void](& cmd /C "sc delete $serviceName")
	        }

	        $statuses = Get-InstanceStatuses
	        if (-not $statuses[$InstanceName]) {
		        Write-Error "The instance '$InstanceName' does not exist."
	        } else {
		        $serviceName = $statuses[$InstanceName]["FullServiceName"]
		        if ($session) { Invoke-Command -Session $session -ScriptBlock $remoteBlock -ArgumentList $serviceName } else { Invoke-Command -ScriptBlock $remoteBlock -ArgumentList $serviceName }
	        }
        }

        function Remove-AllTracesOfHelmFromThisComputer {
            $block = {
                $installDir = Join-Path $env:ProgramFiles "HelmConnect\"
                try {
                    $installDir = $basePathKey.GetValue("InstallDir").ToString()
                } catch { }

                # If there is an uninstaller for the updater then run it now
                $updaterPath = "C:\Program Files\HelmConnect\Updater"
                if ($basePathKey) {
                    $installDir = $basePathKey.GetValue("InstallDir").ToString()
                    $updaterPath = Join-Path $installDir "Updater"
                }
                $updaterUninstallerPath = Join-Path $updaterPath "UpdaterUninstaller.exe"
                if (Test-Path $updaterUninstallerPath) {
                    [void](& $updaterUninstallerPath --silent)
                }

                # send stop command to all helm services
                Get-Service `
                    | Where-Object { $_.Name.StartsWith("helmconnect_", [System.StringComparison]::OrdinalIgnoreCase) } `
                    | % {
                        Stop-Service $_.Name
                    }

                # wait for them all to be stopped
                $allStopped = $false
                $attempt = 0
                while (-not $allStopped -and $attempt -lt 5) {
                    if ($attempt -gt 0) { Start-Sleep 5 }
                    $allStopped = $true
                    $helmServices = Get-Service `
                        | Where-Object { $_.Name.StartsWith("helmconnect_", [System.StringComparison]::OrdinalIgnoreCase) } `
                        | % {
                            if ($_.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
                                $allStopped = $false
                            }
                        }
                    $attempt += 1
                }
                
                # delete services
                Get-WmiObject -Class Win32_Service `
                    | Where-Object { $_.Name.StartsWith("helmconnect_", [System.StringComparison]::OrdinalIgnoreCase) } `
                    | % {
                        [void]($_.Delete())
                    }

                # kill the ProgramData dir
                $programDataPath = [environment]::getfolderpath("commonapplicationdata")
                $helmConnectPath = (Join-Path $programDataPath "\Edoc\HelmConnect")
                if (Test-Path $helmConnectPath) {
                    Remove-Item $helmConnectPath -Recurse -Force
                }

                # kill directory in Program Files
                if ($installDir -ne $null) {
                    Remove-Item $installDir -Force -Recurse
                }       
            }

            if ($session) { Invoke-Command -Session $session -ScriptBlock $block } else { Invoke-Command -ScriptBlock $block }
        }

        ###############################################################################
        # Other helper functions
        ###############################################################################
        #function Invoke-HelmCommand() {
        #    param($session, $scriptBlock, $ArgumentList, [switch]$NoPipe)
        #
        #    if (-not $NoPipe) {
        #        if ($session -eq $null) {
        #            $input | Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $ArgumentList
        #        } else {
        #            $input | Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $ArgumentList
        #        }
        #    } else {
        #        if ($session -eq $null) {
        #            Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $ArgumentList
        #        } else {
        #            Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $ArgumentList
        #        }
        #    }
        #
        #    
        #}

        function Get-Config {
            $blocks = {
		        $programDataPath = [environment]::getfolderpath("commonapplicationdata")
		        $helmConnectPath = (Join-Path $programDataPath "\edoc\HelmConnect")
		        $instanceFilePath = (Join-Path $helmConnectPath "instances.json")
		        if ((Test-Path $instanceFilePath)) {
			        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
			        $jsonText = [System.IO.File]::ReadAllText((Resolve-Path $instanceFilePath))
			        $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
			        return $ser.DeserializeObject($jsonText)
		        } else {
		        	Write-Error "Could not find instances config file at $instanceFilePath."
			        return $null
		        }
	        }

	        if ($session) {Invoke-Command -Session $session -ScriptBlock $blocks} else {Invoke-Command -ScriptBlock $blocks}
        }

        function Check-Server {

            $blocks = {

                #powershell version
                $curPsVer = $PSVersionTable.PSVersion.Major
                if ($curPsVer -lt 3) {
                    $isGoodPs = "False"
                }
                else {
                    $isGoodPs = "True"
                }
                

                #.NET Frame version
                $isGoodNetFrame = "False"
                if ($PSVersionTable.CLRVersion.Major -lt 4) {
                    $curNetVer = $PSVersionTable.CLRVersion.Major
                }
                elseif ($PSVersionTable.CLRVersion.Revision -gt 17000) {
                    $curNetVer = "4.5"
                    $isGoodNetFrame = "True"
                }
                else {
                    $curNetVer = "4"
                }
        
                # OS version 
                $curOsVer = (Get-WmiObject -class Win32_OperatingSystem).Caption
                if ((Get-WmiObject -class Win32_OperatingSystem).version -ge 6.1) {
                    $isGoodOs = "True"
                }
                else{
                    $isGoodOs = "False"
                }

                Function New-VersionObject ($name='', $actualVersion='', $requiredVersion='', $isGood='' )
                {
                    New-Object -TypeName psObject -Property @{name = $name; actualVersion=$actualVersion; requiredVersion=$requiredVersion; isGood=$isGood}
                }

                $names = 'OS','.NET Framework' , 'Powershell'
 
                $objectCollection = $names |
                    ForEach-Object {
                        $nameCurrent = $_
                        
                        if ($nameCurrent -eq 'OS') {
                            $actualversion = $curOsVer
                            $requiredVersion = 'Windows 7+ or Windows Server 2012+'
                            $isGood = $isGoodOs
                        }
                        elseif ($nameCurrent -eq 'Powershell') {
                            $actualversion = $curPsVer
                            $requiredVersion = '3.0+'
                            $isGood = $isGoodPs
                        }
                        else {$actualversion = $curNetVer
                            $requiredVersion = '4.5+'
                            $isGood = $isGoodNetFrame
                        }
 
                   New-VersionObject -name $nameCurrent -actualVersion $actualversion -requiredVersion $requiredVersion -isGood  $isGood | select name, actualversion, requiredVersion, isGood 
                   }
                $objectCollection | Format-Table –AutoSize 

	            }

	        if ($session) 
                {Invoke-Command -Session $session -ScriptBlock $blocks} 
            else
                {Invoke-Command -ScriptBlock $blocks}

            

        }

        function Install-Certificate {
            if ([string]::IsNullOrWhitespace($CertPath )) {
                Write-InvalidUsage "CertPath  parameter required"
            }

            if ([string]::IsNullOrWhitespace($port )) {
                Write-InvalidUsage "Port  parameter required"
            }

            if ([string]::IsNullOrWhitespace($CertPassword )) {
                Write-InvalidUsage "CertPassword  parameter required"
            }

            $makeTempDir = {
                param($dir)
                [void](New-Item $dir -Type directory)
            }

            $killTempDir = {
                param($dir)
                [void](Remove-Item -Recurse -Force $dir)
            }

            $tempDir = "C:\Temp\$([Guid]::NewGuid())"

            # Create a folder to the target server
            if ($session) {
                Invoke-Command -Session $session -ScriptBlock $makeTempDir -ArgumentList $tempDir 
            }else{
                Invoke-Command  -ScriptBlock $makeTempDir -ArgumentList $tempDir 
            }

            TRY {
                # Copy SSL certificate to target server
           
                $Certname = Split-Path $CertPath -leaf
                $destination = (Join-Path $tempDir $Certname)
                Send-File $CertPath $destination $session
                
                $blocks = { 
                    param($Port, $CertPassword)
                    $CertificatePath = $CertPath
                    $pfxcert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                    $pfxcert.Import($destination, $CertPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]"PersistKeySet")
                    $store = Get-Item Cert:\LocalMachine\My
                    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]"ReadWrite")
                    $store.add($pfxcert)
                    $store.Close()
                    $appID = "a7a3fc21-5db4-4311-a6c4-7f8107f570aa"
                    $getCert = Get-ChildItem -Path Cert:\LocalMachine\My
                    $certHash = $pfxcert.Thumbprint
                    $ipport = '0.0.0.0' +':'+ $port
                    $expressionDel= "netsh http delete sslcert ipport=" + $ipport
                    $null= Invoke-Expression $expressionDel
                    $expressionAdd= "netsh http add sslcert ipport=" + $ipport
                    $expressionAdd += " certhash=" + $certHash
                    $expressionAdd += " appid='" + '{'+ $appID + '}'+"'"
                    Invoke-Expression $expressionAdd 
                    }
        
                if ($session) {
                        Invoke-Command -Session $session -ScriptBlock $blocks -ArgumentList $Port, $CertPassword 
                    } else {
                        Invoke-Command -ScriptBlock $blocks -ArgumentList $Port, $CertPassword
                    }
            } 
            finally {
                if ($session){
                    Invoke-Command -Session $session -ScriptBlock $killTempDir -ArgumentList $tempDir
                } else {
                    Invoke-Command -ScriptBlock $killTempDir -ArgumentList $tempDir
                }
            }
        }

        function Configure-Acl
        {
            $blocks = {
		        $programDataPath = [environment]::getfolderpath("commonapplicationdata")
		        $helmConnectPath = (Join-Path $programDataPath "\edoc\HelmConnect")
		        $instanceFilePath = (Join-Path $helmConnectPath "instances.json")
		        if ((Test-Path $instanceFilePath)) {
			        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
                    $jsonText = [System.IO.File]::ReadAllText((Resolve-Path $instanceFilePath))
                    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
                    $value = $ser.DeserializeObject($jsonText)
                    $keys = $value.keys
                    foreach ($key in $keys) {
                    Write-Host $key
                        $ports +=$value."$key".Modules.Helm.WebHost.Bindings
                        }
                    }
                $name = $Env:username
                foreach ($port in $ports) {
                   $expressionDel= "netsh http delete urlacl url=" + $port + "/"
                    $null= Invoke-Expression $psobj$expressionDel
                    $expressionAdd = "netsh http add urlacl url=" + $port + "/"
                    $expressionAdd += " user = " + $name
                    Write-Host $expressionAdd
                    Invoke-Expression $expressionAdd 
                    }
                }
            if ($session) {
                    Invoke-Command -Session $session -ScriptBlock $blocks
                } else {
                    Invoke-Command -ScriptBlock $blocks
                }
        }

        function Get-AvailableHelmVersions {
	        $remoteBlock = {
		        if (-not (Test-Path "HKLM:\Software\Edoc\HelmConnect")) {
                    Write-Host "The reg key 'HKLM:\Software\Edoc\HelmConnect' was not found"
                    return $null
                }

		        $basePath = (Get-ItemProperty -Path "HKLM:\Software\Edoc\HelmConnect").InstallDir

		        if ([string]::IsNullOrWhitespace($basePath)) {
			        Write-Host "The reg value 'InstallDir' was not found in key 'HKLM:\Software\Edoc\HelmConnect'"
		        }
                $versionsDir = Join-Path $basePath "versions"

                if (-not (Test-Path $versionsDir)) {
                    return $null
                }

		        return [System.IO.Directory]::GetDirectories($versionsDir)
	        }

	        if ($session) {Invoke-Command -Session $session -ScriptBlock $remoteBlock} else {Invoke-Command -ScriptBlock $remoteBlock}
        }

        function Get-InstallDir {

        }

        function Get-HelmInstallExists {
	        return (Get-AvailableHelmVersions -ne $null)
        }

        function Get-InstanceStatuses {
            $config = Get-Config

            $block = {
		        [void][System.Reflection.Assembly]::LoadWithPartialName("System.ServiceProcess")
		        $services = [System.ServiceProcess.ServiceController]::GetServices() | Where-Object {$_.Name.StartsWith("HelmNext_") -or $_.Name.StartsWith("HelmConnect_")}
		        $result = @{}
                foreach ($service in $services) {
			        [void][System.Reflection.Assembly]::LoadWithPartialName("System.ServiceProcess")
			        $key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64).OpenSubKey("SYSTEM\CurrentControlSet\Services\$($service.Name)")
			        $value = $key.GetValue("ImagePath").ToString()
			        $key.Close()
			        if ($value.StartsWith('"')) {
				        $value = [System.Text.RegularExpressions.Regex]::Match($value, '"([^"]+)"').Groups[1].Value
			        }
			        $exePath = [System.Environment]::ExpandEnvironmentVariables($value)
			        $info = @{}
			        try {
				        $info["Version"] = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath).FileVersion
			        } catch {
				        $info["Version"] = "<<INVALID>>"
			        }
			        $serviceController = New-Object System.ServiceProcess.ServiceController($service.Name)
			        $info["Status"] = $serviceController.Status.ToString()
			        $info["FullServiceName"] = $service.Name
                    $info["ServerName"] = [System.Net.Dns]::GetHostName()
			        $result[$service.Name.Split("_", 2)[1]] = $info
			        $serviceController.Dispose()
		        }
		        return $result
	        }
            $instanceInfos = @{}
	        $services = if ($session) {Invoke-Command -Session $session -ScriptBlock $block} else {Invoke-Command -ScriptBlock $block}
            
	        if ($config -ne $null) {
		        $config.Keys | % {
			        $name = $_
			        $configVersion = $config[$name]["Version"]
			        $serviceInfo = $services[$name]
			        if (-not $serviceInfo) {
				        $serviceInfo = @{ "Version" = "<<NONE>>"; "Status" = "<<NONE>>"; "FullServiceName" = "HelmConnect_$name" }
			        }
			        $instanceInfos[$name] = @{ "Name" = $name; "FullServiceName" = $serviceInfo["FullServiceName"]; "Status" = $serviceInfo["Status"]; "ConfigVersion" = $configVersion; "ServiceVersion" = $serviceInfo["Version"] }
		        }
	        }

	        $services.Keys | % {
		        $name = $_
		        if ($config -eq $null){ #-or (-not $config[$name])) {
			        $serviceInfo = $services[$name]
			        $instanceInfos[$name] = @{ "Name" = $name; "FullServiceName" = $serviceInfo["FullServiceName"]; "Status" = $serviceInfo["Status"]; "ConfigVersion" = "<<NONE>>"; "ServiceVersion" = $serviceInfo["Version"] }
		        }
	        }

	        return $instanceInfos
        }

        

        function Write-InvalidUsage {
	        param($msg)
	        Write-Host $msg
	        Write-Usage
	        Throw "exit"
        }

        function Write-Usage {
	        Write-Host "--- Expected usage:"
	        Write-Host ""
	        Write-Host "  Manage-Helm -Server localhost -Command <COMMAND> [options]"
	        Write-Host ""
	        Write-Host "Note: If you are using localhost then you can omit the Server parameter."
	        #Write-Host "  you still need PowerShell remoting to be enabled."
	        Write-Host ""
	        Write-Host "--- Examples:"
	        Write-Host ""
	        Write-Host "  View this help information:"
	        Write-Host "   Manage-Helm -Command help"
	        Write-Host ""
	        Write-Host "  Get the status of all instances on a server:"
	        Write-Host "   Manage-Helm -Server localhost -Command status"
	        Write-Host ""
	        Write-Host "  Change the instance configuration of remote server from local json file:"
	        Write-Host "   Manage-Helm -Server localhost -Command config -ConfigPath .\helm.json"
	        Write-Host ""
	        Write-Host "  Change the instance configuration of remote server from specified text:"
	        Write-Host "   Manage-Helm -Server localhost -Command config -ConfigText `$json"
	        Write-Host ""
	        Write-Host "  Read the instance config text from specified server:"
	        Write-Host "   Manage-Helm -Server localhost -Command getconfig"
	        Write-Host ""
	        Write-Host "  Install HelmConnect on remote server from local 7z package:"
	        Write-Host "   Manage-Helm -Server localhost -Command install -InstallPackage .\HelmConnect_1.2.3.4.7z"
	        Write-Host ""
	        Write-Host "  Completely remove HelmConnect from remote server:"
	        Write-Host "   Manage-Helm -Server localhost -Command uninstall"
	        Write-Host ""
	        Write-Host "  Start (and create if needed) a specific instance's Windows service:"
	        Write-Host "   Manage-Helm -Server localhost -Command start -InstanceName test"
	        Write-Host ""
	        Write-Host "  Stop a specific instance's Windows service:"
	        Write-Host "   Manage-Helm -Server localhost -Command stop -InstanceName test"
	        Write-Host ""
	        Write-Host "  Delete a specific instance's Windows service:"
	        Write-Host "   Manage-Helm -Server localhost -Command delete -InstanceName test"
	        Write-Host ""
	        Write-Host "  Pre-requisite detection:"
	        Write-Host "   Manage-Helm -Command checkServer -Server localhost "
	        Write-Host ""
	        Write-Host "  Install SSL certificate:"
	        Write-Host "   Manage-Helm -Server localhost -Command InstallCert -CertPath C:\path\to\cert.pfx -Port 443 -CertPassword foobar "
		    Write-Host ""
	        Write-Host "  Configure ACL:"
	        Write-Host "   Manage-Helm -Server localhost -Command ConfigureAcl "
			Write-Host ""
		    Write-Host "  Send arbitrarily large file to remote machine:"
		    Write-Host "   Manage-Helm -Command send-file -Server serverName -source C:\path\to\source.file -destination C:\path\to\destination.file " 
		    Write-Host ""
            Write-Host "  Provision Sql Server on remote machine:"
            Write-Host "   Manage-Helm -Command provision-sql -Server serverName -SqlISOPath C:\path\to\SQL_ISO  -SQLSYSADMINACCOUNT Machine\User -INSTALLSHAREDDIR C:\Path(optional) -INSTALLSHAREDWOWDIR C:\Path(optional) -INSTANCEDIR C:\Path(optional)"            
            Write-Host ""
            Write-Host "  Completely uninstall Helm:"
            Write-Host "   Manage-Helm -Command wipe -Server serverName"            
            Write-Host ""            

		
        }
		
		function Provision-SQL
		{
			if ([string]::IsNullOrWhitespace($SqlISOPath)) {
				Write-InvalidUsage "SqlISOPath parameter required"
			}
			
			if ([string]::IsNullOrWhitespace($SQLSYSADMINACCOUNT)) {
				Write-InvalidUsage "SQLSYSADMINACCOUNT parameter required. Example: Computername\Admin"
			}

			if ([string]::IsNullOrWhitespace($INSTALLSHAREDDIR)) {
				Write-Host "Empty INSTALLSHAREDDIR parameter, defaulting to C:\Program Files\Microsoft SQL Server"
				$INSTALLSHAREDDIR = "C:\Program Files\Microsoft SQL Server"
			}
			
			if ([string]::IsNullOrWhitespace($INSTALLSHAREDWOWDIR)) {
				Write-Host "Empty INSTALLSHAREDWOWDIR parameter, defaulting to C:\Program Files (x86)\Microsoft SQL Server"
				$INSTALLSHAREDWOWDIR = "C:\Program Files (x86)\Microsoft SQL Server"
			}
			
			if ([string]::IsNullOrWhitespace($INSTANCEDIR)) {
				Write-Host "Empty INSTANCEDIR parameter, defaulting to C:\Program Files\Microsoft SQL Server"
				$INSTANCEDIR = "C:\Program Files\Microsoft SQL Server"
			}

			#makes a temp directory on remote machine
			#copyies the sql iso into this temp directory. 
			$makeTempDir = {
				param($dir, $source)						
				[void](New-Item $dir -Type directory)
				$foundSource = Test-Path $source
				if(!$foundSource) {
					Write-Host "Error. Couldn't find path: "$source" Is the path correct, and accessible by the remote machine?"
					return $false
				}

				$sourcePath = (Resolve-Path $source)
				Write-Host "Copying ISO "$source" to new Temp Directory "$dir 
				Write-Host "Copying..."
				Copy-Item $sourcePath $dir
				return $true

			}

	        $killTempDir = {
		        param($dir)
		        [void](Remove-Item -Recurse -Force $dir)
	        }

	        $tempDir = "C:\Temp\$([Guid]::NewGuid())"
            $result = Invoke-Command -Session $session -ScriptBlock $makeTempDir -ArgumentList $tempDir, $SqlISOPath 
			if(!$result) {
				throw "exit"
			}

			try {                                           
				$remoteScript = {				
					param($tempDir,$SqlISOPath, $SQLSYSADMINACCOUNT, $INSTALLSHAREDDIR, $INSTALLSHAREDWOWDIR, $INSTANCEDIR)
					
					#Check for .net 3.5 installed. SQL 2012 requires 3.5.
					$dotNetTest = test-path 'HKLM:\SOFTWARE\Microsoft\Net Framework Setup\NDP\v3.5'
					if(!$dotNetTest) {
						Write-Host ".Net v3.5 not found in HKEY Local Machine. Please install or turn on .Net 3.5 feature"
						return $false
					}
					
					$before = (Get-Volume).DriveLetter					
					$isoName = Get-ChildItem -name $SqlISOPath
					$isoInstallPath = (Join-Path $tempDir $isoName)							
					Write-Host "ISO Name: "$isoName
					write-host "ISO Install Path: "$isoInstallPath

					$diskNo = Mount-DiskImage -ImagePath $isoInstallPath  
					$driveLetter = (Get-DiskImage $isoInstallPath | Get-Volume).DriveLetter	
					write-host "Mounted ISO to Drive Letter" $driveletter

					$Installerpath = (Resolve-Path ($driveLetter+":\"))
					Push-Location $Installerpath
					Write-Host "Installing"

					./Setup.exe `
					/ACTION="Install" `
					/ENU="TRUE" `
					/QUIET="TRUE" `
					/UpdateEnabled="False" `
					/FEATURES="SQLENGINE" `
					/HELP="False" `
					/INDICATEPROGRESS="True" `
					/x86="False" `
					/INSTALLSHAREDDIR=$INSTALLSHAREDDIR `
					/INSTALLSHAREDWOWDIR=$INSTALLSHAREDWOWDIR `
					/INSTANCENAME="MSSQLSERVER" `
					/INSTANCEID="MSSQLSERVER" `
					/SQMREPORTING="FALSE" `
					/ERRORREPORTING="FALSE" `
					/INSTANCEDIR=$INSTANCEDIR `
					/AGTSVCACCOUNT="NT Service\SQLSERVERAGENT" `
					/AGTSVCSTARTUPTYPE="Manual" `
					/COMMFABRICPORT="0" `
					/COMMFABRICNETWORKLEVEL="0" `
					/COMMFABRICENCRYPTION="0" `
					/MATRIXCMBRICKCOMMPORT="0" `
					/SQLSVCSTARTUPTYPE="Automatic" `
					/FILESTREAMLEVEL="0" `
					/ENABLERANU="False" `
					/SQLCOLLATION="Latin1_General_CI_AS" `
					/SQLSVCACCOUNT="NT Service\MSSQLSERVER" `
					/SQLSYSADMINACCOUNTS=$SQLSYSADMINACCOUNT `
					/ADDCURRENTUSERASSQLADMIN="False" `
					/TCPENABLED="1" `
					/NPENABLED="0" `
					/BROWSERSVCSTARTUPTYPE="Disabled" `
					/IACCEPTSQLSERVERLICENSETERMS="1"
					
					if($LASTEXITCODE -ne 0) {
						Write-Host "Install failed with Error code: "$LASTEXITCODE
					} else {
						Write-Host "Install finished"				
					}
					Pop-Location
					Dismount-DiskImage -ImagePath $isoInstallPath
				}					
				if ($session) {
					Invoke-Command -Session $session -ScriptBlock $remoteScript -ArgumentList $tempDir, $SqlISOPath, $SQLSYSADMINACCOUNT, $INSTALLSHAREDDIR, $INSTALLSHAREDWOWDIR, $INSTANCEDIR
				} else {
					Invoke-Command -ScriptBlock $remoteScript -ArgumentList $tempDir, $SqlISOPath, $SQLSYSADMINACCOUNT, $INSTALLSHAREDDIR, $INSTALLSHAREDWOWDIR, $INSTANCEDIR
				}
			} finally {
				if ($session) {
					Invoke-Command -Session $session -ScriptBlock $killTempDir -ArgumentList $tempDir
				} else {
					Invoke-Command -ScriptBlock $killTempDir -ArgumentList $tempDir
				}
			}			
		}

		function Zip-File($sourceFile, $zipFileName)
		{
			if (Test-Path $zipFileName){
				Write-Error "Zip file $zipFileName already exists. Cannot overwrite file."
				Throw
			}
		 	& $7z a -tzip $zipFileName $sourceFile
		}

		function Setup-NodeUpdatePackage{
            Write-Error "Setup-NodeUpdatePackage is no longer applicable"
		}

        function Test-PsRemoting 
        { 
            $computerName = $env:computername
            
            try 
            { 
                $errorActionPreference = "Stop"

                If (-not [string]::IsNullOrEmpty($Server)){
                	if ($Credential -ne $null){
                		$result = Test-Connection -ComputerName $Server { 1 } -Credential $Credential
                	}else{
                		$result = Test-Connection -ComputerName $Server { 1 }
                	}
                }
               
                else{
                	$result = Invoke-Command -ComputerName $computername { 1 }
                }
            } 
            catch 
            { 
                Write-Verbose $_ 
                return $false 
            } 
    
            if($result -ne 1) 
            { 
                Write-Verbose "Remoting to $computerName returned an unexpected result." 
                return $false 
            } 
    
            $true    
        }
        ###############################################################################
        # Universal validation
        ###############################################################################
        #$psRemoting = Test-PsRemoting
        
        if ((-not [string]::IsNullOrEmpty($Server)) -and ($session -eq $null)) {
            
    		if ($Credential -ne $null){
        		$session = New-PSSession $Server -Credential $Credential
	        }
	        else {
	            $session = New-PSSession $Server 
	        }

            if ([string]::IsNullOrEmpty($session)) {
                return
            }
        }

        ###############################################################################
        # Interpret and invoke commands
        ###############################################################################
        try {
	        if ($Command -eq "status") {
		        Get-Status
	        } elseif ($Command -eq "config") {
                Write-ConfigFile
            } elseif ($Command -eq "wipe") {
                Remove-AllTracesOfHelmFromThisComputer
            } elseif ($Command -eq "getconfig") {
		        Write-Output (Get-ConfigText)
	        } elseif ($Command -eq "install") {
		        Install-Helm
	        } elseif ($Command -eq "uninstall") {
		        Uninstall-Helm
	        } elseif ($Command -eq "start") {
		        Start-Service
	        } elseif ($Command -eq "stop") {
		        Stop-MyService
	        } elseif ($Command -eq "help" -or $Command -eq "?") {
		        Write-Usage
	        } elseif ($Command -eq "delete") {
		        Delete-Service
	        } elseif ($Command -eq "checkServer") {
		        Check-Server
	        } elseif ($Command -eq "installcert") {
		        Install-Certificate
	        } elseif ($Command -eq "ConfigureAcl") {
		        Configure-Acl
			} elseif ($Command -eq "provision-SQL") {
				Provision-SQL			
	        } elseif ($Command -eq "send-file") { 
				Send-File $Source $Destination $session
			} elseif ($Command -eq "package-node-update") {
				Setup-NodeUpdatePackage
            } else {
                Write-Usage 
	        }
        } catch {
            Write-Error $_
        } finally {
	        # If server parameter is used then close the remote session
            if ($session -ne $null -and (-not $NoKillSession)) {
                Remove-PSSession $session
            }
            # Make sure to always close the remote session
	        #Remove-PSSession $session
        }
    } catch {
        if ($_ -eq "exit") {
            return
        }else{
            Write-Error $_
        }
    } finally {
        # If server parameter is used then close the remote session
        if ($session -ne $null -and (-not $NoKillSession)) {
            Remove-PSSession $session
        }
        # Make sure to always close the remote session
        #Remove-PSSession $session
    }
}
