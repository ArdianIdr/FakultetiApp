<#
.SYNOPSIS
  (Për profesorin) Për çdo student: databazë SQL, databazë PostgreSQL, Blob container,
  sekretet në Key Vault-in e përbashkët dhe leje vetëm për sekretet e tij.
  Ekzekutohet PASI studenti të ketë ekzekutuar setup.ps1 (web app ekziston).
.EXAMPLE
  ./scripts/provision-student.ps1 -Student ardian
#>
param([Parameter(Mandatory)][string]$Student)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/common.ps1"
$s = Clean $Student
Run az account set --subscription $SubscriptionId

$sqlDb = "db-$s"
$pgDb  = $s
$sqlPwd = az keyvault secret show --vault-name $SharedKv -n shared-sql-admin-password --query value -o tsv
$pgPwd  = az keyvault secret show --vault-name $SharedKv -n shared-pg-admin-password  --query value -o tsv

Write-Host "== SQL databazë (free offer)" -ForegroundColor Cyan
Run az sql db create -g $SharedRg -s $SharedSql -n $sqlDb --edition GeneralPurpose --family Gen5 --capacity 2 --compute-model Serverless --use-free-limit --free-limit-exhaustion-behavior AutoPause -o none

Write-Host "== PostgreSQL databazë" -ForegroundColor Cyan
Run az postgres flexible-server db create -g $SharedRg -s $SharedPg -d $pgDb -o none

Write-Host "== Blob container" -ForegroundColor Cyan
$stgKey = az storage account keys list -n $SharedStg -g $SharedRg --query "[0].value" -o tsv
Run az storage container create -n "dokumentet-$s" --account-name $SharedStg --account-key $stgKey --public-access blob -o none
$stgCs = az storage account show-connection-string -n $SharedStg -g $SharedRg --query connectionString -o tsv

Write-Host "== Sekretet" -ForegroundColor Cyan
$secrets = @{
    "$s-SqlConnection"      = "Server=tcp:$SharedSql.database.windows.net,1433;Database=$sqlDb;User ID=$Admin;Password=$sqlPwd;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;"
    "$s-PostgresConnection" = "Host=$SharedPg.postgres.database.azure.com;Port=5432;Database=$pgDb;Username=$Admin;Password=$pgPwd;SSL Mode=Require;Trust Server Certificate=true"
    "$s-StorageConnection"  = $stgCs
}
$kvId = az keyvault show -n $SharedKv -g $SharedRg --query id -o tsv
$app = az webapp list -g "rg-$s" --query "[0].name" -o tsv
$principal = $null
if ($app) { $principal = az webapp identity show -n $app -g "rg-$s" --query principalId -o tsv }
else { Write-Host "Web app s'ekziston ende: lejet anashkalohen (rinisni skriptin pasi studenti të bëjë setup.ps1)." -ForegroundColor Yellow }

foreach ($name in $secrets.Keys) {
    Run az keyvault secret set --vault-name $SharedKv -n $name --value $secrets[$name] -o none
    if (-not $principal) { continue }
    # leje vetëm për këtë sekret, jo për të gjithë vault-in
    $scope = "$kvId/secrets/$name"
    Run az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope $scope -o none
}
if ($app) { Run az webapp restart -n $app -g "rg-$s" }
Write-Host "Gati për $s. Web app: https://$app.azurewebsites.net" -ForegroundColor Green
