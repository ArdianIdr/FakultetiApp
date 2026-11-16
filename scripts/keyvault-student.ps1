<#
.SYNOPSIS
  HAPI 2b: Krijon Key Vault-in tuaj dhe e lidh me web app-in.

.DESCRIPTION
  Key Vault është "kasaforta" ku ruhen fjalëkalimet. Kështu fjalëkalimet nuk shkruhen kurrë në kod.
  Çfarë bën ky skript:
    1. Krijon Key Vault-in tuaj kv-<emri>-xxxxx në rg-<emri> (me RBAC, lejet jepen me role).
    2. Ruan 3 sekrete brenda: SqlConnection, PostgresConnection, StorageConnection.
       (Connection string = teksti me adresën e databazës + përdoruesin + fjalëkalimin.)
    3. I jep web app-it rolin "Key Vault Secrets User": lejen për të LEXUAR sekretet.
    4. Vendos te App settings referenca @Microsoft.KeyVault(...): web app-i i lexon vetë vlerat nga Key Vault.
    5. E rinis (restart) web app-in që t'i marrë ndryshimet.
  Kërkon: setup.ps1 të ekzekutuar më parë; vlerat nga docs/te-dhenat-e-klases.md
  (çelësin e Storage e jep profesori).

.EXAMPLE
  ./scripts/keyvault-student.ps1 -Student ardian -SqlPassword "..." -PgPassword "..." -StorageKey "..."
#>
param(
    [Parameter(Mandatory)][string]$Student,        # emri juaj i vogël
    [Parameter(Mandatory)][string]$SqlPassword,    # fjalëkalimi i serverit SQL (nga te-dhenat-e-klases.md)
    [Parameter(Mandatory)][string]$PgPassword,     # fjalëkalimi i PostgreSQL (nga te-dhenat-e-klases.md)
    [Parameter(Mandatory)][string]$StorageKey      # çelësi i Storage (e jep profesori)
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/common.ps1"                        # vlerat e përbashkëta dhe funksionet ndihmëse
$s   = Clean $Student
$rg  = "rg-$s"
$loc = "eastus"
$kv  = "kv-$s-$(Hash5 "$SubscriptionId$s")"         # emri i Key Vault (unik në botë)

Run az account set --subscription $SubscriptionId

# Gjejmë web app-in e krijuar nga setup.ps1; pa të nuk ka kuptim të vazhdojmë
$app = az webapp list -g $rg --query "[0].name" -o tsv
if (-not $app) { throw "Web app në $rg nuk ekziston. Ekzekutoni setup.ps1 më parë." }

# 1) Krijojmë Key Vault, vetëm nëse nuk ekziston (kështu skripti mund të ekzekutohet sërish pa problem)
Write-Host "== Key Vault $kv" -ForegroundColor Cyan
$exists = az keyvault list -g $rg --query "[?name=='$kv'].name" -o tsv
if (-not $exists) { Run az keyvault create -n $kv -g $rg -l $loc --enable-rbac-authorization true -o none }

# 2) Ndërtojmë 3 connection string-ët me të dhënat e serverëve të përbashkët dhe databazave tuaja
$sql = "Server=tcp:$SharedSql.database.windows.net,1433;Database=db-$s;User ID=$Admin;Password=$SqlPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;"
$pg  = "Host=$SharedPg.postgres.database.azure.com;Port=5432;Database=$s;Username=$Admin;Password=$PgPassword;SSL Mode=Require;Trust Server Certificate=true"
$stg = "DefaultEndpointsProtocol=https;AccountName=$SharedStg;AccountKey=$StorageKey;EndpointSuffix=core.windows.net"

Write-Host "== Sekretet" -ForegroundColor Cyan
$secrets = [ordered]@{ SqlConnection = $sql; PostgresConnection = $pg; StorageConnection = $stg }
foreach ($name in $secrets.Keys) {
    # Lejet e porsa dhëna në Azure mund të vonojnë 1-5 minuta të aktivizohen,
    # prandaj provojmë deri në 10 herë, çdo 30 sekonda. Mos e ndërprisni skriptin.
    for ($i = 1; $i -le 10; $i++) {
        $ErrorActionPreference = "Continue"
        $err = az keyvault secret set --vault-name $kv -n $name --value $secrets[$name] -o none 2>&1
        $ok = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = "Stop"
        if ($ok) { break }
        Write-Host "Po pres lejet ($i/10)..."; Start-Sleep 30
    }
    # Pas 10 provave shfaqim gabimin e vërtetë të Azure, që të dihet shkaku
    if (-not $ok) { Write-Host ($err | Out-String) -ForegroundColor Red; throw "Nuk u ruajt sekreti $name" }
}

# 3) Web app-i merr leje vetëm për të lexuar sekretet (jo për t'i ndryshuar)
Write-Host "== Leja për web app-in (Key Vault Secrets User)" -ForegroundColor Cyan
$principal = az webapp identity show -n $app -g $rg --query principalId -o tsv     # ID e identitetit të web app-it
$kvId = az keyvault show -n $kv -g $rg --query id -o tsv
Run az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope $kvId -o none

# 4) App settings: në vend të fjalëkalimit, vendosim "referencë" te sekreti në Key Vault
Write-Host "== App settings me referenca Key Vault" -ForegroundColor Cyan
$settings = [ordered]@{
    "ConnectionStrings__Sql"      = "@Microsoft.KeyVault(VaultName=$kv;SecretName=SqlConnection)"
    "ConnectionStrings__Postgres" = "@Microsoft.KeyVault(VaultName=$kv;SecretName=PostgresConnection)"
    "ConnectionStrings__Storage"  = "@Microsoft.KeyVault(VaultName=$kv;SecretName=StorageConnection)"
    "Blob__Container"             = "dokumentet-$s"
}
$tmp = Join-Path ([IO.Path]::GetTempPath()) "kv-$s.json"      # skedar i përkohshëm (karakteret ; e prishin komandën)
[IO.File]::WriteAllText($tmp, ($settings | ConvertTo-Json))
Run az webapp config appsettings set -n $app -g $rg --settings "@$tmp" -o none
Remove-Item $tmp

# 5) Rinisja, që aplikacioni t'i lexojë referencat
Run az webapp restart -n $app -g $rg
Write-Host "`nGati. Verifikoni: Portal -> $app -> Environment variables -> statusi 'Resolved'." -ForegroundColor Green
