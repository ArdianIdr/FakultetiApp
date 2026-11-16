<#
.SYNOPSIS
  Krijon të gjitha burimet Azure për një student brenda rg-<student>.
.EXAMPLE
  ./scripts/setup.ps1 -Student ardian
#>
param(
    [Parameter(Mandatory)][string]$Student,
    [string]$Location = "eastus",
    [string]$SubscriptionId = "9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb"
)
$ErrorActionPreference = "Stop"
function Run { & $args[0] $args[1..($args.Length-1)]; if ($LASTEXITCODE -ne 0) { throw "Dështoi: $($args -join ' ')" } }

$s   = $Student.ToLower() -replace '[^a-z0-9]', ''
$rg  = "rg-$s"
# prapashtesë e qëndrueshme, që emrat globalë të jenë unikë
$md5 = [Security.Cryptography.MD5]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes("$SubscriptionId$s"))
$sfx = ([BitConverter]::ToString($md5) -replace '-', '').Substring(0, 5).ToLower()

$kv      = "kv-$s-$sfx"
$sqlSrv  = "sql-$s-$sfx"
$sqlDb   = "fakulteti"
$pgSrv   = "psql-$s-$sfx"
$stg     = ("st$s$sfx").Substring(0, [Math]::Min(24, ("st$s$sfx").Length))
$plan    = "plan-$s"
$app     = "app-$s-$sfx"
$admin   = "dbadmin"
function NewPassword { (-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })) + "aA1" }
$sqlPwd = NewPassword
$pgPwd  = NewPassword

Write-Host "== 0. Abonimi dhe provider-at" -ForegroundColor Cyan
Run az account set --subscription $SubscriptionId
foreach ($p in "Microsoft.Sql","Microsoft.DBforPostgreSQL","Microsoft.KeyVault","Microsoft.Storage","Microsoft.Web") {
    Run az provider register --namespace $p --only-show-errors
}

Write-Host "== 1. Resource group (nëse mungon)" -ForegroundColor Cyan
Run az group create -n $rg -l $Location -o none

Write-Host "== 2. Storage Account (Blob)" -ForegroundColor Cyan
Run az storage account create -n $stg -g $rg -l $Location --sku Standard_LRS --kind StorageV2 --allow-blob-public-access true --min-tls-version TLS1_2 -o none
$stgCs = az storage account show-connection-string -n $stg -g $rg --query connectionString -o tsv

Write-Host "== 3. Azure SQL (free offer, serverless)" -ForegroundColor Cyan
Run az sql server create -n $sqlSrv -g $rg -l $Location -u $admin -p $sqlPwd -o none
Run az sql server firewall-rule create -g $rg -s $sqlSrv -n AllowAll --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255 -o none
Run az sql db create -g $rg -s $sqlSrv -n $sqlDb --edition GeneralPurpose --family Gen5 --capacity 2 --compute-model Serverless --use-free-limit --free-limit-exhaustion-behavior AutoPause -o none
$sqlCs = "Server=tcp:$sqlSrv.database.windows.net,1433;Database=$sqlDb;User ID=$admin;Password=$sqlPwd;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;"

Write-Host "== 4. PostgreSQL Flexible Server (Burstable B1ms)" -ForegroundColor Cyan
Run az postgres flexible-server create -n $pgSrv -g $rg -l $Location --tier Burstable --sku-name Standard_B1ms --storage-size 32 --version 16 `
    -u $admin -p $pgPwd --public-access "0.0.0.0-255.255.255.255" --database-name fakulteti --yes -o none
$pgCs = "Host=$pgSrv.postgres.database.azure.com;Port=5432;Database=fakulteti;Username=$admin;Password=$pgPwd;SSL Mode=Require;Trust Server Certificate=true"

Write-Host "== 5. Key Vault (RBAC) dhe sekretet" -ForegroundColor Cyan
Run az keyvault create -n $kv -g $rg -l $Location --enable-rbac-authorization true -o none
$kvId  = az keyvault show -n $kv -g $rg --query id -o tsv
$meId  = az ad signed-in-user show --query id -o tsv
Run az role assignment create --assignee-object-id $meId --assignee-principal-type User --role "Key Vault Secrets Officer" --scope $kvId -o none
Write-Host "   po pres që të propagohen të drejtat (45s)..."; Start-Sleep 45
Run az keyvault secret set --vault-name $kv -n SqlConnection      --value $sqlCs -o none
Run az keyvault secret set --vault-name $kv -n PostgresConnection --value $pgCs  -o none
Run az keyvault secret set --vault-name $kv -n StorageConnection  --value $stgCs -o none

Write-Host "== 6. App Service (F1 Free, Linux, .NET 8)" -ForegroundColor Cyan
Run az appservice plan create -n $plan -g $rg -l $Location --sku F1 --is-linux -o none
Run az webapp create -n $app -g $rg -p $plan --runtime "DOTNETCORE:8.0" -o none
$principal = az webapp identity assign -n $app -g $rg --query principalId -o tsv
Run az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope $kvId -o none
Run az webapp config appsettings set -n $app -g $rg -o none --settings `
    "ConnectionStrings__Sql=@Microsoft.KeyVault(VaultName=$kv;SecretName=SqlConnection)" `
    "ConnectionStrings__Postgres=@Microsoft.KeyVault(VaultName=$kv;SecretName=PostgresConnection)" `
    "ConnectionStrings__Storage=@Microsoft.KeyVault(VaultName=$kv;SecretName=StorageConnection)"

Write-Host "`n== GATI ==" -ForegroundColor Green
Write-Host "Resource group : $rg"
Write-Host "Web app        : $app   (https://$app.azurewebsites.net)"
Write-Host "Key Vault      : $kv"
Write-Host "SQL server     : $sqlSrv"
Write-Host "PostgreSQL     : $pgSrv"
Write-Host "Storage        : $stg"
Write-Host "`nPër GitHub Secrets përdor: APP_NAME = $app"
