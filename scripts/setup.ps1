<#
.SYNOPSIS
  Krijon web app-in në rg-<student> dhe e lidh me sekretet në Key Vault-in e përbashkët.
  Pastaj profesori ekzekuton provision-student.ps1.
.EXAMPLE
  ./scripts/setup.ps1 -Student ardian
#>
param(
    [Parameter(Mandatory)][string]$Student,
    [string]$Location = "eastus"
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/common.ps1"
$s   = Clean $Student
$rg  = "rg-$s"
$app = "app-$s-$(Hash5 "$SubscriptionId$s")"

Run az account set --subscription $SubscriptionId

Write-Host "== App Service (F1 Free, Linux, .NET 10)" -ForegroundColor Cyan
Run az appservice plan create -n "plan-$s" -g $rg -l $Location --sku F1 --is-linux -o none
Run az webapp create -n $app -g $rg -p "plan-$s" --runtime "DOTNETCORE:10.0" -o none
Run az webapp identity assign -n $app -g $rg -o none

# referencat te Key Vault; vlerat lexohen pasi profesori jep lejet
$settings = [ordered]@{
    "ConnectionStrings__Sql"      = "@Microsoft.KeyVault(VaultName=$SharedKv;SecretName=$s-SqlConnection)"
    "ConnectionStrings__Postgres" = "@Microsoft.KeyVault(VaultName=$SharedKv;SecretName=$s-PostgresConnection)"
    "ConnectionStrings__Storage"  = "@Microsoft.KeyVault(VaultName=$SharedKv;SecretName=$s-StorageConnection)"
    "Blob__Container"             = "dokumentet-$s"
}
$tmp = Join-Path ([IO.Path]::GetTempPath()) "settings-$s.json"
[IO.File]::WriteAllText($tmp, ($settings | ConvertTo-Json))
Run az webapp config appsettings set -n $app -g $rg --settings "@$tmp" -o none
Remove-Item $tmp
Write-Host "`n== GATI ==" -ForegroundColor Green
Write-Host "Web app: $app  (https://$app.azurewebsites.net)"
Write-Host "APP_NAME për GitHub Secrets: $app"
Write-Host "Tani profesori ekzekuton: ./scripts/provision-student.ps1 -Student $s"
