$ErrorActionPreference = "Stop"

# Checks enrollment-token and Fleet Server lookups against fake Kibana Fleet
# APIs shaped like each supported stack line (see linux-fleet-versions.sh).

$testDirectory = Split-Path $MyInvocation.MyCommand.Path
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $testDirectory "..\.."))
. (Join-Path $repositoryRoot "src\handler\windows\scripts\helper.ps1")

function Write-Log($message, $level) { }

class FakeHttpException : System.Exception {
    [object]$Response
    FakeHttpException([int]$code) : base("Response status code does not indicate success: $code") {
        $this.Response = [pscustomobject]@{ StatusCode = $code }
    }
}

$script:Scenario = ""
$script:Requests = New-Object System.Collections.Generic.List[string]

function Respond($body) {
    return [pscustomobject]@{ StatusCode = 200; Content = $body }
}

function Invoke-WebRequest {
    param($Uri, $Method, $Headers, $Body, [switch]$UseBasicParsing)
    $script:Requests.Add($Uri)
    $path = $Uri.Substring("https://kibana.example.test".Length)
    switch -Wildcard ("$($script:Scenario):$path") {
        "hosted9-paginated:/api/fleet/enrollment_api_keys" { return Respond '{"items":[{"id":"key-old","active":false,"policy_id":"policy-123"}],"total":2,"page":1,"perPage":1}' }
        "hosted9-paginated:/api/fleet/enrollment_api_keys[?]page=2" { return Respond '{"items":[{"id":"key-azure","active":true,"policy_id":"policy-123"}],"total":2,"page":2,"perPage":1}' }
        "hosted9*:/api/fleet/enrollment_api_keys/key-azure" { return Respond '{"item":{"id":"key-azure","api_key":"token-azure","policy_id":"policy-123","active":true}}' }
        "hosted9*:/api/fleet/enrollment_api_keys" { return Respond '{"items":[{"id":"key-other","active":true,"policy_id":"other-policy"},{"id":"key-old","active":false,"policy_id":"policy-123"},{"id":"key-azure","api_key":"token-azure","active":true,"policy_id":"policy-123"}],"total":3,"page":1,"perPage":20}' }
        "hosted9*:/api/fleet/enrollment-api-keys*" { throw [FakeHttpException]::new(404) }
        "hosted9*:/api/fleet/settings" { return Respond '{"item":{"id":"fleet-default-settings"}}' }
        "hosted9*:/api/fleet/fleet_server_hosts" { return Respond '{"items":[{"host_urls":["https://other.example.test:443"],"is_default":false},{"host_urls":["https://fleet9.example.test:443"],"is_default":true}]}' }

        "hosted8:/api/fleet/enrollment?api?keys/key-azure" { return Respond '{"item":{"id":"key-azure","api_key":"token-azure","policy_id":"policy-123","active":true}}' }
        "hosted8:/api/fleet/enrollment?api?keys" { return Respond '{"list":[{"id":"key-azure","active":true,"policy_id":"policy-123"}],"items":[{"id":"key-azure","active":true,"policy_id":"policy-123"}]}' }
        "hosted8:/api/fleet/settings" { return Respond '{"item":{"fleet_server_hosts":["https://fleet8.example.test:443"]}}' }
        "hosted8:/api/fleet/fleet_server_hosts" { return Respond '{"items":[{"host_urls":["https://fleet8.example.test:443"],"is_default":true}]}' }

        "legacy:/api/fleet/enrollment-api-keys/key-azure" { return Respond '{"item":{"id":"key-azure","api_key":"token-azure","policy_id":"policy-123","active":true}}' }
        "legacy:/api/fleet/enrollment-api-keys" { return Respond '{"list":[{"id":"key-other","active":true,"policy_id":"other-policy"}],"total":2,"page":1,"perPage":1}' }
        "legacy:/api/fleet/enrollment-api-keys[?]page=2" { return Respond '{"list":[{"id":"key-azure","active":true,"policy_id":"policy-123"}],"total":2,"page":2,"perPage":1}' }
        "legacy:/api/fleet/enrollment_api_keys*" { throw [FakeHttpException]::new(404) }
        "legacy:/api/fleet/fleet_server_hosts" { throw [FakeHttpException]::new(404) }
        "legacy:/api/fleet/settings" { return Respond '{"item":{"fleet_server_hosts":["https://fleet7.example.test:443"]}}' }
    }
    throw "unexpected request in $($script:Scenario): $Uri"
}

function Assert-Equal($expected, $actual, $description) {
    if ($expected -ne $actual) {
        throw "not ok - $description`: expected '$expected', got '$actual'"
    }
}

$headers = @{ "Authorization" = "ApiKey encoded"; "kbn-xsrf" = "true" }
$cases = @(
    @{ Scenario = "hosted9"; FleetServer = "https://fleet9.example.test:443" },
    @{ Scenario = "hosted9-paginated"; FleetServer = "https://fleet9.example.test:443" },
    @{ Scenario = "hosted8"; FleetServer = "https://fleet8.example.test:443" },
    @{ Scenario = "legacy"; FleetServer = "https://fleet7.example.test:443" }
)
foreach ($case in $cases) {
    $script:Scenario = $case.Scenario
    $script:Requests.Clear()
    $token = Get-EnrollmentToken "https://kibana.example.test" $headers "policy-123"
    Assert-Equal "token-azure" $token "$($case.Scenario) enrollment token"
    $fleetServer = Get-FleetServerUrl "https://kibana.example.test" $headers
    Assert-Equal $case.FleetServer $fleetServer "$($case.Scenario) Fleet Server URL"
    if ($case.Scenario -like "hosted9*" -and ($script:Requests | Where-Object { $_ -like "*enrollment-api-keys*" })) {
        throw "not ok - 9.x flow must not call the removed enrollment-api-keys endpoint"
    }
    Write-Output "ok - Windows $($case.Scenario) Fleet enrollment lookups"
}

$script:Scenario = "hosted9-paginated"
$errorMessage = $null
try {
    Get-EnrollmentToken "https://kibana.example.test" $headers "missing-policy" | Out-Null
} catch {
    $errorMessage = $_.Exception.Message
}
Assert-Equal "No active enrollment token found for policy missing-policy" $errorMessage "a policy without an active enrollment token is rejected after the last page"
Write-Output "ok - Windows missing enrollment token is rejected"
