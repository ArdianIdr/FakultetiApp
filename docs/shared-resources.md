# Burimet e përbashkëta me Azure CLI (një nga një)

Ekzekutoji në PowerShell, një bllok në herë. Zëvendëso `<SUFIKS>` me 4-5 shkronja/numra unikë (p.sh. `7k2x9`), sepse emrat e SQL, Key Vault dhe Storage duhet të jenë unikë globalisht.

## 0. Hyrja dhe variablat
```powershell
az login --tenant e7dd866d-a284-43a6-90aa-9aad6684a2f0
az account set --subscription 9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb

$loc    = "eastus"
$sfx    = "<SUFIKS>"
$rg     = "rg-shared"
$kv     = "kv-fakulteti-$sfx"
$sql    = "sql-fakulteti-$sfx"
$pg     = "psql-fakulteti-$sfx"
$stg    = "stfakulteti$sfx"
$admin  = "dbadmin"
$sqlPwd = "Sql!" + [guid]::NewGuid().ToString("N").Substring(0,16)
$pgPwd  = "Pg!"  + [guid]::NewGuid().ToString("N").Substring(0,16)
```

## 1. Resource group
```powershell
az group create -n $rg -l $loc
```

## 2. Storage Account (Blob)
```powershell
az storage account create -n $stg -g $rg -l $loc --sku Standard_LRS --kind StorageV2 --allow-blob-public-access true --min-tls-version TLS1_2
```

## 3. SQL Server + firewall
```powershell
az sql server create -n $sql -g $rg -l $loc -u $admin -p $sqlPwd
az sql server firewall-rule create -g $rg -s $sql -n AllowAll --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255
```
Databazat (falas, serverless) krijohen për çdo student:
```powershell
az sql db create -g $rg -s $sql -n db-ardian --edition GeneralPurpose --family Gen5 --capacity 2 --compute-model Serverless --use-free-limit --free-limit-exhaustion-behavior AutoPause
```

## 4. PostgreSQL Flexible Server
```powershell
az postgres flexible-server create -n $pg -g $rg -l $loc --tier Burstable --sku-name Standard_B1ms --storage-size 32 --version 16 -u $admin -p $pgPwd --public-access 0.0.0.0-255.255.255.255 --yes
```
Databaza për çdo student:
```powershell
az postgres flexible-server db create -g $rg -s $pg -d ardian
```

## 5. Key Vault (RBAC) dhe leja jote
```powershell
az keyvault create -n $kv -g $rg -l $loc --enable-rbac-authorization true
$kvId = az keyvault show -n $kv -g $rg --query id -o tsv
$me   = az ad signed-in-user show --query id -o tsv
az role assignment create --assignee-object-id $me --assignee-principal-type User --role "Key Vault Secrets Officer" --scope $kvId
```
Prit rreth 1 minutë që leja të propagohet, pastaj:
```powershell
az keyvault secret set --vault-name $kv -n shared-sql-admin-password --value $sqlPwd
az keyvault secret set --vault-name $kv -n shared-pg-admin-password  --value $pgPwd
```

## 6. Blob container dhe sekretet për një student (p.sh. ardian)
```powershell
$key = az storage account keys list -n $stg -g $rg --query "[0].value" -o tsv
az storage container create -n dokumentet-ardian --account-name $stg --account-key $key --public-access blob
$stgCs = az storage account show-connection-string -n $stg -g $rg --query connectionString -o tsv

az keyvault secret set --vault-name $kv -n ardian-SqlConnection      --value "Server=tcp:$sql.database.windows.net,1433;Database=db-ardian;User ID=$admin;Password=$sqlPwd;Encrypt=True;Connection Timeout=60;"
az keyvault secret set --vault-name $kv -n ardian-PostgresConnection --value "Host=$pg.postgres.database.azure.com;Port=5432;Database=ardian;Username=$admin;Password=$pgPwd;SSL Mode=Require;Trust Server Certificate=true"
az keyvault secret set --vault-name $kv -n ardian-StorageConnection  --value $stgCs
```

## 7. Leja e web app-it të studentit vetëm për sekretet e veta
(Pasi studenti të ketë krijuar web app-in me `setup.ps1`.)
```powershell
$principal = az webapp identity show -n <APP_NAME> -g rg-ardian --query principalId -o tsv
foreach ($n in "SqlConnection","PostgresConnection","StorageConnection") {
  az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope "$kvId/secrets/ardian-$n"
}
az webapp restart -n <APP_NAME> -g rg-ardian
```

## 8. Pas mësimit
```powershell
az postgres flexible-server stop -g $rg -n $pg      # ndalon PostgreSQL
```

Shënim: `setup.ps1` dhe `provision-student.ps1` llogarisin emrat e përbashkët me një prapashtesë nga hash. Nëse krijon burimet me këtë udhëzues, vendos të njëjtat emra në `scripts/common.ps1` (`$SharedKv`, `$SharedSql`, `$SharedPg`, `$SharedStg`), përndryshe skriptet nuk do t'i gjejnë.
