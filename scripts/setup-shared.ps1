<#
.SYNOPSIS
  (Për profesorin, vetëm një herë) Krijon burimet e përbashkëta në rg-shared:
  SQL server, PostgreSQL server, Key Vault dhe Storage Account.
#>
param([string]$Location = "eastus")
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/common.ps1"

Run az account set --subscription $SubscriptionId
# Regjistrojmë shërbimet (provider) që subscription-i të mund t'i përdorë
foreach ($p in "Microsoft.Sql","Microsoft.DBforPostgreSQL","Microsoft.KeyVault","Microsoft.Storage","Microsoft.Web") {
    Run az provider register --namespace $p --only-show-errors
}
Run az group create -n $SharedRg -l $Location -o none   # grupi i përbashkët

Write-Host "== Storage" -ForegroundColor Cyan
# Storage Account për Blob (skedarë/dokumente)
Run az storage account create -n $SharedStg -g $SharedRg -l $Location --sku Standard_LRS --kind StorageV2 --allow-blob-public-access true --min-tls-version TLS1_2 -o none

Write-Host "== SQL server" -ForegroundColor Cyan
$sqlPwd = NewPassword   # fjalëkalim i rastësishëm
# Firewall i hapur për të gjitha IP-të (vetëm për klasën; mos e përdorni në prodhim)
Run az sql server create -n $SharedSql -g $SharedRg -l $Location -u $Admin -p $sqlPwd -o none
Run az sql server firewall-rule create -g $SharedRg -s $SharedSql -n AllowAll --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255 -o none

Write-Host "== PostgreSQL server" -ForegroundColor Cyan
$pgPwd = NewPassword
Run az postgres flexible-server create -n $SharedPg -g $SharedRg -l $Location --tier Burstable --sku-name Standard_B1ms --storage-size 32 --version 16 `
    -u $Admin -p $pgPwd --public-access "0.0.0.0-255.255.255.255" --yes -o none

Write-Host "== Key Vault (RBAC)" -ForegroundColor Cyan
# Key Vault i profesorit; lejet jepen me role (RBAC), ju merrni rolin Secrets Officer për të shkruar sekrete
Run az keyvault create -n $SharedKv -g $SharedRg -l $Location --enable-rbac-authorization true -o none
$kvId = az keyvault show -n $SharedKv -g $SharedRg --query id -o tsv
$meId = az ad signed-in-user show --query id -o tsv
Run az role assignment create --assignee-object-id $meId --assignee-principal-type User --role "Key Vault Secrets Officer" --scope $kvId -o none
Write-Host "   po pres të drejtat (45s)..."; Start-Sleep 45
# fjalëkalimet e adminit ruhen vetëm në Key Vault
Run az keyvault secret set --vault-name $SharedKv -n shared-sql-admin-password --value $sqlPwd -o none
Run az keyvault secret set --vault-name $SharedKv -n shared-pg-admin-password  --value $pgPwd  -o none

Write-Host "`n== GATI ==" -ForegroundColor Green
"KeyVault: $SharedKv`nSQL: $SharedSql`nPostgreSQL: $SharedPg`nStorage: $SharedStg"
