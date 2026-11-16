<#
.SYNOPSIS
  (Për studentin) Krijon Key Vault-in tuaj në rg-<emri>, ruan connection string-ët si sekrete,
  i jep web app-it lejen për t'i lexuar dhe e lidh me referenca Key Vault.
  Kërkon: setup.ps1 të ekzekutuar më parë; vlerat nga docs/te-dhenat-e-klases.md.
.EXAMPLE
  ./scripts/keyvault-student.ps1 -Student ardian -SqlPassword "..." -PgPassword "..." -StorageKey "..."
#>
param(
    [Parameter(Mandatory)][string]$Student,
    [Parameter(Mandatory)][string]$SqlPassword,
    [Parameter(Mandatory)][string]$PgPassword,
    [Parameter(Mandatory)][string]$StorageKey
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/common.ps1"
$s   = Clean $Student
$rg  = "rg-$s"
$loc = "eastus"
$kv  = "kv-$s-$(Hash5 "$SubscriptionId$s")"

Run az account set --subscription $SubscriptionId
$app = az webapp list -g $rg --query "[0].name" -o tsv
if (-not $app) { throw "Web app në $rg nuk ekziston. Ekzekutoni setup.ps1 më parë." }

Write-Host "== Key Vault $kv" -ForegroundColor Cyan
$exists = az keyvault list -g $rg --query "[?name=='$kv'].name" -o tsv
if (-not $exists) { Run az keyvault create -n $kv -g $rg -l $loc --enable-rbac-authorization true -o none }

$sql = "Server=tcp:$SharedSql.database.windows.net,1433;Database=db-$s;User ID=$Admin;Password=$SqlPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;"
$pg  = "Host=$SharedPg.postgres.database.azure.com;Port=5432;Database=$s;Username=$Admin;Password=$PgPassword;SSL Mode=Require;Trust Server Certificate=true"
$stg = "DefaultEndpointsProtocol=https;AccountName=$SharedStg;AccountKey=$StorageKey;EndpointSuffix=core.windows.net"

Write-Host "== Sekretet" -ForegroundColor Cyan
$secrets = [ordered]@{ SqlConnection = $sql; PostgresConnection = $pg; StorageConnection = $stg }
foreach ($name in $secrets.Keys) {
    # lejet RBAC mund të vonojnë disa minuta
    for ($i = 1; $i -le 10; $i++) {
        $ErrorActionPreference = "Continue"
        az keyvault secret set --vault-name $kv -n $name --value $secrets[$name] -o none 2>$null
        $ok = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = "Stop"
        if ($ok) { break }
        Write-Host "Po pres lejet ($i/10)..."; Start-Sleep 30
    }
    if (-not $ok) { throw "Nuk u ruajt sekreti $name" }
}

Write-Host "== Leja për web app-in (Key Vault Secrets User)" -ForegroundColor Cyan
$principal = az webapp identity show -n $app -g $rg --query principalId -o tsv
$kvId = az keyvault show -n $kv -g $rg --query id -o tsv
Run az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope $kvId -o none

Write-Host "== App settings me referenca Key Vault" -ForegroundColor Cyan
$settings = [ordered]@{
    "ConnectionStrings__Sql"      = "@Microsoft.KeyVault(VaultName=$kv;SecretName=SqlConnection)"
    "ConnectionStrings__Postgres" = "@Microsoft.KeyVault(VaultName=$kv;SecretName=PostgresConnection)"
    "ConnectionStrings__Storage"  = "@Microsoft.KeyVault(VaultName=$kv;SecretName=StorageConnection)"
    "Blob__Container"             = "dokumentet-$s"
}
$tmp = Join-Path ([IO.Path]::GetTempPath()) "kv-$s.json"
[IO.File]::WriteAllText($tmp, ($settings | ConvertTo-Json))
Run az webapp config appsettings set -n $app -g $rg --settings "@$tmp" -o none
Remove-Item $tmp
Run az webapp restart -n $app -g $rg
Write-Host "`nGati. Verifikoni: Portal -> $app -> Environment variables -> statusi 'Resolved'." -ForegroundColor Green
