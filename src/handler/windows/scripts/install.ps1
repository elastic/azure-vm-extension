$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory log.ps1)
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory helper.ps1)

# install script ran at the installation time, nothing to be configured at this point
Write-Log "Install command has been executed. Elastic Agent will be installed on enable" "INFO"

