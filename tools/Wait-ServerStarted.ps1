param(
    [Parameter(Mandatory=$true)][string] $Url,
    [int] $MaxTries,
    [int] $WaitPeriod
)

function Wait-HelmReady() {
    if ($MaxTries -eq 0) {
        $maxFailCount = 20
    } else {
        $maxFailCount = $MaxTries
    }
    
    if ($WaitPeriod -eq 0) {
        $sleepTime = 2
    } else {
        $sleepTime = $WaitPeriod
    }
    
    $failCount = 0
    
    $apiStatusUri = $url + "/api/v1/system/info"
    Write-Verbose "Waiting for Helm to start..."
    
    while ($true) {
        try {
            $helmStatus = (Invoke-RestMethod $apiStatusUri | Select -ExpandProperty "Data")
            $databaseUp = $helmStatus.DatabaseUp
            $databaseStatus = $helmStatus.DatabaseStatus
            
            if ($databaseUp -eq "True" -and $databaseStatus -eq "OK") {
                # Often when /system/info says it's ready it's actually not quite ready.
                Start-Sleep 10
                Write-Verbose "Helm service and database ready for requests"
                Exit 0
            } elseif ($failCount -lt $maxFailCount) {
                Write-Verbose "Database not ready, retrying."
                $failCount += 1
                Start-Sleep $sleepTime
            } else {
                # Api call has completed but the database hasn't started properly. Abort!!
                Write-Error "Service started but database not OK. Giving up."
                Write-Error "DatabaseStatus: $databaseStatus,\n DatabaseUp: $databaseUp"
                Exit 1
            }
        } catch {
            $failCount += 1
            if ($failCount -lt $maxFailCount) {
                Start-Sleep $sleepTime
                Write-Verbose "Helm service not ready, retrying."
            } else {
                # Invoke-RestMethod keeps on failing. Something is probably wrong with the api endpoint.
                Write-Error "Could not connect to api endpoint after $maxFailCount attempts"
                Write-Error "Verify server $Server accepts api requests to $apiStatusUri."
                Exit 1
            }
        }
    }
}

Wait-HelmReady