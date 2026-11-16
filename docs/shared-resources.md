# Burimet e përbashkëta (për profesorin)

Këto krijohen **një herë** nga profesori në `rg-shared`. Mënyra e shpejtë: `./scripts/setup-shared.ps1`. Më poshtë janë komandat një nga një (për demonstrim).

Emrat aktualë (shih edhe `scripts/common.ps1`):

| Burimi | Emri | Rajoni |
|---|---|---|
| Resource group | `rg-shared` | eastus |
| Key Vault | `kv-fakulteti-f7k2q` | eastus |
| Storage | `stfakultetif7k2q` | eastus |
| SQL server | `sql-fakulteti-zmusi` | swedencentral |
| PostgreSQL | `psql-fakulteti-qzpml` | uksouth |

> Rajonet janë të ndryshme sepse subscription-i nuk lejoi SQL/PostgreSQL në `eastus`. Emrat SQL, Key Vault, Storage dhe web app janë globalë, prandaj kanë prapashtesë të rastësishme.

## 0. Hyrja dhe variablat
```powershell
az login --tenant e7dd866d-a284-43a6-90aa-9aad6684a2f0
az account set --subscription 9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb

$sfx    = "<SUFIKS>"          # 4-5 shkronja/numra unikë
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
az group create -n $rg -l eastus
```

## 2. Storage Account (Blob)
```powershell
az storage account create -n $stg -g $rg -l eastus --sku Standard_LRS --kind StorageV2 --allow-blob-public-access true --min-tls-version TLS1_2
```

## 3. SQL Server + firewall
```powershell
az sql server create -n $sql -g $rg -l swedencentral -u $admin -p $sqlPwd
az sql server firewall-rule create -g $rg -s $sql -n AllowAll --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255
```
Databaza falas (serverless) për çdo student:
```powershell
az sql db create -g $rg -s $sql -n db-ardian --edition GeneralPurpose --family Gen5 --capacity 2 --compute-model Serverless --use-free-limit --free-limit-exhaustion-behavior AutoPause
```

## 4. PostgreSQL Flexible Server
```powershell
az postgres flexible-server create -n $pg -g $rg -l uksouth --tier Burstable --sku-name Standard_B1ms --storage-size 32 --version 16 -u $admin -p $pgPwd --public-access 0.0.0.0-255.255.255.255 --yes
az postgres flexible-server db create -g $rg -s $pg -d ardian
```

## 5. Key Vault i përbashkët (opsional, kopje e fjalëkalimeve)
```powershell
az keyvault create -n $kv -g $rg -l eastus --enable-rbac-authorization true
$kvId = az keyvault show -n $kv -g $rg --query id -o tsv
$me   = az ad signed-in-user show --query id -o tsv
az role assignment create --assignee-object-id $me --assignee-principal-type User --role "Key Vault Secrets Officer" --scope $kvId
```
Prit rreth 1 minutë, pastaj:
```powershell
az keyvault secret set --vault-name $kv -n shared-sql-admin-password --value $sqlPwd
az keyvault secret set --vault-name $kv -n shared-pg-admin-password  --value $pgPwd
```

## 6. Për çdo student: databazat, container-i dhe rolet
Ekzekuto `./scripts/provision-student.ps1 -Student ardian`. Ai krijon `db-ardian`, databazën PostgreSQL `ardian`, container-in `dokumentet-ardian` dhe sekretet rezervë në Key Vault-in e përbashkët.

Rolet e studentit në `rg-<emri>` (Contributor ekziston; shto këto dy):
```powershell
$id = az ad user list --query "[?starts_with(userPrincipalName,'ardian.')].id | [0]" -o tsv
$sc = "/subscriptions/9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb/resourceGroups/rg-ardian"
az role assignment create --assignee-object-id $id --assignee-principal-type User --role "Key Vault Administrator"   --scope $sc
az role assignment create --assignee-object-id $id --assignee-principal-type User --role "User Access Administrator" --scope $sc
```
Këto lejojnë studentin të krijojë Key Vault-in e vet dhe t'i japë web app-it leje, vetëm brenda grupit të vet.

## 7. Pas mësimit
```powershell
az postgres flexible-server stop -g $rg -n $pg      # ndalon PostgreSQL (kushton)
```
Ndërro fjalëkalimet e serverëve dhe çelësin e Storage.

Nëse krijon burimet me emra të tjerë, vendosi te `scripts/common.ps1` (`$SharedKv`, `$SharedSql`, `$SharedPg`, `$SharedStg`).
