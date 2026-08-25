$ErrorActionPreference = "Stop"

$testDirectory = Split-Path $MyInvocation.MyCommand.Path
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $testDirectory "..\.."))
. (Join-Path $repositoryRoot "src\handler\windows\scripts\helper.ps1")

function Assert-Equal($expected, $actual, $description) {
    if ($expected -ne $actual) {
        throw "$description`: expected '$expected', got '$actual'"
    }
}

$headers = New-AuthorizationHeaders `
    -ApiKey "encoded-api-key" `
    -Username "fallback-user" `
    -Password "fallback-password" `
    -Base64Auth ([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("base64-user:base64-password"))) `
    -IncludeXsrf $true
Assert-Equal "ApiKey encoded-api-key" $headers["Authorization"] "API key takes precedence"
Assert-Equal "true" $headers["kbn-xsrf"] "Kibana requests include the XSRF header"

$headers = New-AuthorizationHeaders `
    -ApiKey "" `
    -Username "fallback-user" `
    -Password "fallback-password" `
    -Base64Auth "" `
    -IncludeXsrf $false
$expectedBasic = [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes("fallback-user:fallback-password")
)
Assert-Equal "Basic $expectedBasic" $headers["Authorization"] "username/password fallback"

$encodedBasic = [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes("base64-user:base64-password")
)
$headers = New-AuthorizationHeaders `
    -ApiKey "" `
    -Username "" `
    -Password "" `
    -Base64Auth $encodedBasic `
    -IncludeXsrf $false
Assert-Equal "Basic $encodedBasic" $headers["Authorization"] "base64Auth fallback"

$failed = $false
try {
    New-AuthorizationHeaders `
        -ApiKey "" `
        -Username "" `
        -Password "" `
        -Base64Auth "" `
        -IncludeXsrf $false
} catch {
    $failed = $true
}
Assert-Equal $true $failed "missing credentials are rejected"

Write-Output "ok - Windows authentication selection tests passed"
