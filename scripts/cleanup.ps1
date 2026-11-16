<#
.SYNOPSIS
  Pas mësimit: -StopOnly ndalon PostgreSQL të përbashkët; përndryshe fshin web app-in dhe të dhënat e studentit.
#>
param([Parameter(Mandatory)][string]$Student, [switch]$StopOnly)
. "$PSScriptRoot/common.ps1"
$s = Clean $Student
az account set --subscription $SubscriptionId
if ($StopOnly) {
    # PostgreSQL është kostoja kryesore; riniset automatikisht pas 7 ditësh
    az postgres flexible-server stop -g $SharedRg -n $SharedPg
    return
}
# Fshirja e plotë e studentit: burimet në rg-<emri>, pastaj databazat, container-i dhe sekretet në burimet e përbashkëta
$ids = az resource list -g "rg-$s" --query "[].id" -o tsv
if ($ids) { az resource delete --ids $ids.Split("`n") }   # fshin web app, plan, Key Vault etj.
az sql db delete -g $SharedRg -s $SharedSql -n "db-$s" --yes
az postgres flexible-server db delete -g $SharedRg -s $SharedPg -d $s --yes
$key = az storage account keys list -n $SharedStg -g $SharedRg --query "[0].value" -o tsv
az storage container delete -n "dokumentet-$s" --account-name $SharedStg --account-key $key
foreach ($n in "SqlConnection","PostgresConnection","StorageConnection") { az keyvault secret delete --vault-name $SharedKv -n "$s-$n" }