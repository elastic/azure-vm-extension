function GetDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = GetDirectory

$extensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")
$deploy = $scriptDir + "\deploy\"
$scriptDir = $extensionRoot + "\src\handler\"

function Add-Zip
{
    param([string]$zipfilename)
    $dir = $scriptDir + $zipfilename
    $compress = @{
        LiteralPath= "$dir\HandlerManifest.json", "$dir\scripts"
        CompressionLevel = "Fastest"
        DestinationPath = "$deploy\$zipfilename.zip"
    }
    Compress-Archive @compress  -Force
}

function Add-Zip-Linux
{
    param([string]$zipfilename)
    $dir = $scriptDir + $zipfilename
    $compress = @{
        LiteralPath= "$dir\HandlerManifest.json", "$dir\install.sh", "$dir\enable.sh", "$dir\disable.sh", "$dir\uninstall.sh", "$dir\update.sh","$dir\newconfig.sh", "$dir\helper.sh"
        CompressionLevel = "Fastest"
        DestinationPath = "$deploy\$zipfilename.zip"
    }
    Compress-Archive @compress  -Force
}

Add-Zip "windows"
Add-Zip-Linux "linux"

