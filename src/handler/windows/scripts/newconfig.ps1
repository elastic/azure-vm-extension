$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory log.ps1)
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory helper.ps1)

# neconfig script used during enable time, will help will uninstalling the elastic agent previously configured, it will try to retrieve the previous configuration and uninstall/remove folders for the elastic agent

# for status
$name = "Uninstall elastic agent"
$firstOperation = "unenrolling elastic agent"
$secondOperation = "uninstalling elastic agent and removing any elastic agent related folders"
$operation = "uninstalling elastic agent and removing any elastic agent related folders"
$message = "Uninstall elastic agent"
$subName = "Elastic Agent"

function Uninstall-Old-ElasticAgent {
    $INSTALL_LOCATION="C:\Program Files"
    $retries = 3
    $retryCount = 0
    $completed = $false
    while (-not $completed) {
        Try
        {
            Write-Log "Uninstalling Elastic Agent" "INFO"
            & "$INSTALL_LOCATION\Elastic\Agent\elastic-agent.exe" uninstall --force
            Write-Log "Elastic Agent has been uninstalled" "INFO"
            Write-Log "removing directories" "INFO"
            Remove-Item "$INSTALL_LOCATION\Elastic\Agent" -Recurse -Force
            Remove-Item "$INSTALL_LOCATION\Elastic-Agent" -Recurse -Force
            Write-Log "elastic agent directories removed" "INFO"
            Write-Status "$name" "$operation" "success" "$message" "$subName" "success" "Elastic Agent service has been uninstalled"
            $completed = $true
        }
        Catch {
            if ($retryCount -ge $retries) {
                Write-Log "Elastic Agent installation failed after 3 retries" "ERROR"
                Write-Log $_ "ERROR"
                Write-Log $_.ScriptStackTrace "ERROR"
                Write-Status "$name" "$operation" "error" "$message" "$subName" "error" "Elastic Agent service has been uninstalled"
                Clean-And-Exit 1
            } else {
                Write-Log "Elastic Agent installation failed. retrying in 20s" "ERROR"
                Write-Log $_ "ERROR"
                Write-Log $_.ScriptStackTrace "ERROR"
                sleep 20
                $retryCount++
            }
        }
    }
}
