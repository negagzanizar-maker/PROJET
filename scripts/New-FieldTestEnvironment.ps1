param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ServerHost,

    [ValidateRange(1, 65535)]
    [int] $HttpsPort = 7443,

    [ValidateRange(1, 65535)]
    [int] $PostgresPort = 55432,

    [string] $OutputDirectory = (Join-Path (Get-Location) '.data/field-test')
)

$ErrorActionPreference = 'Stop'

$parsedAddress = $null
if ([System.Net.IPAddress]::TryParse($ServerHost, [ref] $parsedAddress) -and
    [System.Net.IPAddress]::IsLoopback($parsedAddress)) {
    throw 'ServerHost must be the laptop LAN address visible from the Raspberry Pi, not a loopback address.'
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $outputRoot) {
    throw "Refusing to overwrite the existing field-test directory: $outputRoot"
}

$databaseName = 'display_control'
$databaseUser = 'display_control_owner'
$composeProjectName = 'display-control-field-test'
$databasePasswordBytes = New-Object byte[] 32
$databaseRandom = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $databaseRandom.GetBytes($databasePasswordBytes)
}
finally {
    $databaseRandom.Dispose()
}
$databasePassword = -join ($databasePasswordBytes | ForEach-Object { $_.ToString('x2') })
$databaseConnectionString = "Host=127.0.0.1;Port=$PostgresPort;Database=$databaseName;Username=$databaseUser;Password=$databasePassword"

& (Join-Path $PSScriptRoot 'New-DevelopmentSecurityMaterial.ps1') `
    -DatabaseConnectionString $databaseConnectionString `
    -OutputDirectory $outputRoot `
    -HttpsHost $ServerHost `
    -HttpsPort $HttpsPort

$composeEnvironmentPath = Join-Path $outputRoot 'compose.env'
$composeEnvironment = @"
POSTGRES_DB=$databaseName
POSTGRES_USER=$databaseUser
POSTGRES_PASSWORD=$databasePassword
POSTGRES_PORT=$PostgresPort
CLAMAV_PORT=3310
"@
[System.IO.File]::WriteAllText($composeEnvironmentPath, $composeEnvironment)

function Quote-PowerShellSingle([string] $value) {
    return "'" + $value.Replace("'", "''") + "'"
}

$launcherPath = Join-Path $outputRoot 'start-field-test-server.ps1'
$apiLauncherPath = Join-Path $outputRoot 'run-api.local.ps1'
$launcher = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $(Quote-PowerShellSingle $repositoryRoot)

`$previousErrorActionPreference = `$ErrorActionPreference
`$ErrorActionPreference = 'SilentlyContinue'
docker info *> `$null
`$dockerInfoExitCode = `$LASTEXITCODE
`$ErrorActionPreference = `$previousErrorActionPreference
if (`$dockerInfoExitCode -ne 0) {
    throw 'Docker Desktop is not running. Start it and run this script again.'
}

docker compose --project-name '$composeProjectName' --env-file $(Quote-PowerShellSingle $composeEnvironmentPath) up -d postgres clamav
if (`$LASTEXITCODE -ne 0) { throw 'Docker Compose failed to start PostgreSQL and ClamAV.' }

`$postgresReady = `$false
foreach (`$attempt in 1..60) {
    `$previousErrorActionPreference = `$ErrorActionPreference
    `$ErrorActionPreference = 'SilentlyContinue'
    docker compose --project-name '$composeProjectName' --env-file $(Quote-PowerShellSingle $composeEnvironmentPath) exec -T postgres pg_isready -U '$databaseUser' -d '$databaseName' *> `$null
    `$probeExitCode = `$LASTEXITCODE
    `$ErrorActionPreference = `$previousErrorActionPreference
    if (`$probeExitCode -eq 0) { `$postgresReady = `$true; break }
    Start-Sleep -Seconds 2
}
if (-not `$postgresReady) { throw 'PostgreSQL did not become ready within two minutes.' }

`$clamAvReady = `$false
foreach (`$attempt in 1..150) {
    `$previousErrorActionPreference = `$ErrorActionPreference
    `$ErrorActionPreference = 'SilentlyContinue'
    docker compose --project-name '$composeProjectName' --env-file $(Quote-PowerShellSingle $composeEnvironmentPath) exec -T clamav clamdscan --ping 1 *> `$null
    `$probeExitCode = `$LASTEXITCODE
    `$ErrorActionPreference = `$previousErrorActionPreference
    if (`$probeExitCode -eq 0) { `$clamAvReady = `$true; break }
    Start-Sleep -Seconds 2
}
if (-not `$clamAvReady) { throw 'ClamAV did not become ready within five minutes.' }

`$env:DISPLAYCONTROL_MIGRATION_CONNECTION=$(Quote-PowerShellSingle $databaseConnectionString)
dotnet tool restore
if (`$LASTEXITCODE -ne 0) { throw 'The pinned dotnet-ef tool could not be restored.' }
dotnet ef database update --project src/DisplayControl.Infrastructure --startup-project src/DisplayControl.Api
if (`$LASTEXITCODE -ne 0) { throw 'Database migration failed.' }

npm.cmd run build --workspace admin-web
if (`$LASTEXITCODE -ne 0) { throw 'The administration application build failed.' }

Write-Host 'Field-test server starting at https://${ServerHost}:$HttpsPort'
Write-Host 'Keep this window open during the Raspberry Pi test.'
& $(Quote-PowerShellSingle $apiLauncherPath)
"@
[System.IO.File]::WriteAllText($launcherPath, $launcher)

$serverCaPath = Join-Path $outputRoot 'field-test-server-ca.crt'
Write-Host ''
Write-Host 'Field-test environment created.'
Write-Host "1. Trust the local CA for the current Windows user (one time):"
Write-Host "   Import-Certificate -FilePath '$serverCaPath' -CertStoreLocation Cert:\CurrentUser\Root"
Write-Host "2. Start Docker Desktop."
Write-Host "3. Start the complete server: & '$launcherPath'"
Write-Host "4. Open https://${ServerHost}:$HttpsPort"
Write-Host "5. Give the Pi installer this public CA: $serverCaPath"
