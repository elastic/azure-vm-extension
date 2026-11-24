$ErrorActionPreference = "Stop"

# Checks how Resolve-AgentVersion picks the Elastic Agent version
# (see linux-agent-version.sh for the rules).

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

$script:AvailableVersions = $null
$script:EsRoot = $null

function Invoke-WebRequest {
    param($Uri, $Method, $Headers, $Body, [switch]$UseBasicParsing)
    switch ($Uri) {
        "https://kibana.example.test/api/fleet/agents/available_versions" {
            if ($script:AvailableVersions -is [int]) { throw [FakeHttpException]::new($script:AvailableVersions) }
            return [pscustomobject]@{ StatusCode = 200; Content = $script:AvailableVersions }
        }
        "https://es.example.test" { return [pscustomobject]@{ StatusCode = 200; Content = $script:EsRoot } }
    }
    throw "unexpected request: $Uri"
}

function Resolve($name, $available, $esRoot) {
    $script:AvailableVersions = $available
    $script:EsRoot = $esRoot
    return Resolve-AgentVersion "https://kibana.example.test" "https://es.example.test" @{ "Authorization" = "ApiKey x" }
}

function Expect-Version($name, $available, $esRoot, $expected) {
    $actual = Resolve $name $available $esRoot
    if ($actual -ne $expected) { throw "not ok - $name`: expected '$expected', got '$actual'" }
    Write-Output "ok - Windows agent version: $name"
}

$hostedEs = '{"version":{"number":"9.5.6","build_flavor":"default"}}'
Expect-Version "Fleet list, latest first" '{"items":["9.5.6","9.5.5"]}' $hostedEs "9.5.6"
Expect-Version "Fleet list, build item skipped" '{"items":["9.5.4+build202609161310","9.5.4"]}' $hostedEs "9.5.4"
Expect-Version "Kibana before 8.4 falls back to Elasticsearch" 404 '{"version":{"number":"8.3.3","build_flavor":"default"}}' "8.3.3"
Expect-Version "key without Fleet agent read falls back to Elasticsearch" 403 $hostedEs "9.5.6"
Expect-Version "Serverless uses the Fleet list" '{"items":["9.6.0"]}' '{"version":{"number":"8.11.0","build_flavor":"serverless"}}' "9.6.0"

$failed = $false
try { Resolve "serverless" 404 '{"version":{"number":"8.11.0","build_flavor":"serverless"}}' | Out-Null } catch { $failed = $true }
if (-Not $failed) { throw "not ok - Serverless without Fleet list must be rejected" }
Write-Output "ok - Windows agent version: Serverless without Fleet list is rejected"
