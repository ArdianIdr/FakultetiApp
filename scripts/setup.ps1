<#
.SYNOPSIS
  HAPI 1: Krijon web app-in tuaj në grupin rg-<emri>.

.DESCRIPTION
  Çfarë bën ky skript:
    1. Krijon një App Service Plan (serveri ku do të ekzekutohet aplikacioni), niveli B1 (Basic, me pagesë të vogël; F1 falas ka kuotë 60 min CPU/ditë dhe bllokohet).
    2. Krijon Web App-in (aplikacionin .NET 10) mbi atë plan.
    3. Aktivizon Managed Identity: një "identitet" i web app-it, me të cilin më vonë do të
       hyjë në Key Vault pa fjalëkalim.
    4. Vendos një "app setting" me emrin e container-it Blob të studentit.
  Në fund shfaq APP_NAME: shënojeni, do ta vendosni si sekret në GitHub.
  Hapi tjetër: ./scripts/keyvault-student.ps1

.EXAMPLE
  ./scripts/setup.ps1 -Student ardian
#>
param(
    [Parameter(Mandatory)][string]$Student,   # emri juaj i vogël, p.sh. ardian
    [string]$Location = "eastus"              # rajoni i Azure ku krijohet
)
# Në rast gabimi, skripti ndalet menjëherë (në vend që të vazhdojë gabimisht)
$ErrorActionPreference = "Stop"

# Ngarkon vlerat e përbashkëta (subscription, emrat e serverëve) dhe funksionet ndihmëse nga common.ps1
. "$PSScriptRoot/common.ps1"

$s   = Clean $Student                                   # emri i pastruar: shkronja të vogla, pa hapësira
$rg  = "rg-$s"                                          # grupi juaj i resurseve
$app = "app-$s-$(Hash5 "$SubscriptionId$s")"            # emri i web app-it; prapashtesa e shkurtër e bën unik në mbarë botën

# Zgjedh subscription-in e klasës (që komandat të ekzekutohen aty)
Run az account set --subscription $SubscriptionId

Write-Host "== App Service (B1, Linux, .NET 10)" -ForegroundColor Cyan
# 1) App Service Plan: "serveri" (B1 = Basic, --is-linux = sistem Linux)
Run az appservice plan create -n "plan-$s" -g $rg -l $Location --sku B1 --is-linux -o none
# 2) Web App: aplikacioni që do të hapet në internet, me runtime .NET 10
Run az webapp create -n $app -g $rg -p "plan-$s" --runtime "DOTNETCORE:10.0" -o none
# 3) Managed Identity: identiteti i aplikacionit për Key Vault
Run az webapp identity assign -n $app -g $rg -o none

# 4) App settings: variabla mjedisi që aplikacioni i lexon (këtu emri i container-it për dokumentet)
#    Connection string-ët i vendos hapi tjetër (keyvault-student.ps1)
$settings = [ordered]@{
    "Blob__Container" = "dokumentet-$s"
}
# I shkruajmë në një skedar të përkohshëm JSON, sepse karakteret speciale në komandë mund ta prishin
$tmp = Join-Path ([IO.Path]::GetTempPath()) "settings-$s.json"
[IO.File]::WriteAllText($tmp, ($settings | ConvertTo-Json))
Run az webapp config appsettings set -n $app -g $rg --settings "@$tmp" -o none
Remove-Item $tmp

Write-Host "`n== GATI ==" -ForegroundColor Green
Write-Host "Web app: $app  (https://$app.azurewebsites.net)"
Write-Host "APP_NAME për GitHub Secrets: $app"
Write-Host "Hapi tjetër: ./scripts/keyvault-student.ps1 (shih docs/te-dhenat-e-klases.md)"
