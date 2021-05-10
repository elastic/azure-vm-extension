$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory log.ps1)
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory helper.ps1)

#update script is ran at update time during a vm extension update, will set flag that this is an update operation

Write-Log "Update command has been triggered. Elastic Agent reinstall" "INFO"

Write-Log "Update env variable is set" "INFO"
Set-UpdateEnvVariables
