<#
.SYNOPSIS
  (Për studentin) Kontrollon çfarë keni krijuar deri tani dhe ju tregon çfarë mungon.
  Nuk ndryshon asgjë, vetëm lexon. Mund ta ekzekutoni sa herë të doni.
.EXAMPLE
  ./scripts/kontrollo.ps1 -Student ardian
#>
param([Parameter(Mandatory)][string]$Student)
$ErrorActionPreference = "Continue"
. "$PSScriptRoot/common.ps1"
$s  = Clean $Student
$rg = "rg-$s"
$script:ok = 0; $script:bad = 0   # numëruesit e kontrolleve të kaluara / të dështuara

# Kontrollo: shfaq [OK] në të gjelbër nëse kushti është i vërtetë; përndryshe [MUNGON] në të kuqe me këshillën se çfarë të bëni
function Kontrollo($titulli, $kushti, $keshille) {
    if ($kushti) { Write-Host "  [OK]     $titulli" -ForegroundColor Green; $script:ok++ }
    else { Write-Host "  [MUNGON] $titulli" -ForegroundColor Red; Write-Host "           -> $keshille" -ForegroundColor Yellow; $script:bad++ }
}
# Az1: ekzekuton komandën az pa shfaqur gabime; nëse dështon kthen $null (që skripti të mos ndalet)
function Az1 { $r = & az @args 2>$null; if ($LASTEXITCODE -ne 0) { return $null }; return $r }

Write-Host "`nKontrolli për $rg" -ForegroundColor Cyan

Write-Host "`n[Hapi 0] Hyrja në Azure" -ForegroundColor Cyan
$sub = Az1 account show --query id -o tsv   # subscription-i aktual i loguar
Kontrollo "Jeni loguar në Azure" ($null -ne $sub) "az login --tenant $TenantId"
Kontrollo "Subscription i saktë" ($sub -eq $SubscriptionId) "az account set --subscription $SubscriptionId"
if ($sub -ne $SubscriptionId) { Write-Host "`nNuk mund të vazhdoj pa hyrjen e saktë." -ForegroundColor Red; return }
$rgOk = (Az1 group exists -n $rg) -eq "true"
Kontrollo "Grupi $rg ekziston dhe e shihni" $rgOk "Kontrolloni shkrimin e emrit (-Student) ose njoftoni profesorin"
if (-not $rgOk) { return }

Write-Host "`n[Hapi 1] Web app" -ForegroundColor Cyan
$app = Az1 webapp list -g $rg --query "[0].name" -o tsv
Kontrollo "Web app ekziston" ([bool]$app) "./scripts/setup.ps1 -Student $s"
if ($app) {
    # Running = aplikacioni është i ndezur; identiteti = lejon hyrjen në Key Vault pa fjalëkalim
    $state = Az1 webapp show -n $app -g $rg --query state -o tsv
    Kontrollo "Web app është Running" ($state -eq "Running") "Në Portal: web app -> Overview -> Start"
    $mi = Az1 webapp identity show -n $app -g $rg --query principalId -o tsv
    Kontrollo "Managed Identity është aktive" ([bool]$mi) "az webapp identity assign -n $app -g $rg"
    Write-Host "           APP_NAME = $app" -ForegroundColor DarkGray
}

Write-Host "`n[Hapi 2b] Key Vault" -ForegroundColor Cyan
$kv = Az1 keyvault list -g $rg --query "[0].name" -o tsv
Kontrollo "Key Vault ekziston" ([bool]$kv) "./scripts/keyvault-student.ps1 -Student $s ..."
if ($kv) {
    # Duhet të ekzistojnë 3 sekretet me connection string-ët
    $secrets = Az1 keyvault secret list --vault-name $kv --query "[].name" -o tsv
    foreach ($n in "SqlConnection", "PostgresConnection", "StorageConnection") {
        Kontrollo "Sekreti $n" ($secrets -contains $n) "Ekzekutoni përsëri keyvault-student.ps1"
    }
}
if ($app) {
    # Pyesim Azure (REST API) a i ka lexuar web app-i referencat te Key Vault: statusi duhet të jetë "Resolved"
    $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$rg/providers/Microsoft.Web/sites/$app/config/configreferences/appsettings?api-version=2022-03-01"
    $refs = Az1 rest --method get --url $url -o json | ConvertFrom-Json
    foreach ($r in $refs.value) {
        $st = $r.properties.status
        Kontrollo "$($r.name) -> Key Vault: $st" ($st -eq "Resolved") "Prisni 2 min dhe bëni Restart te web app (leja po përhapet)"
    }
    if (-not $refs.value) { Kontrollo "Referencat Key Vault te App settings" $false "Ekzekutoni keyvault-student.ps1" }
}

Write-Host "`n[Hapi 5] Aplikacioni online" -ForegroundColor Cyan
if ($app) {
    # Hapim faqen /Studentet; kodi 200 = aplikacioni punon dhe lidhet me databazën
    try { $code = (Invoke-WebRequest "https://$app.azurewebsites.net/Studentet" -UseBasicParsing -TimeoutSec 60).StatusCode } catch { $code = $_.Exception.Response.StatusCode.value__ }
    Kontrollo "https://$app.azurewebsites.net/Studentet kthen 200 (kodi: $code)" ($code -eq 200) "Bëni deploy nga GitHub Actions (hapi 5) ose shihni Log stream"
}

Write-Host "`n[Mësimi 2] Monitorimi, Queue, Function (opsionale)" -ForegroundColor Cyan
$ai = Az1 resource list -g $rg --resource-type microsoft.insights/components --query "[0].name" -o tsv
Kontrollo "Application Insights" ([bool]$ai) "Shihni docs/mesimi-2-appinsights-function.md"
$stq = Az1 storage account list -g $rg --query "[0].name" -o tsv
Kontrollo "Storage account (për Queue)" ([bool]$stq) "Shihni docs/mesimi-2-appinsights-function.md"
$fn = Az1 functionapp list -g $rg --query "[0].name" -o tsv
Kontrollo "Azure Function" ([bool]$fn) "Shihni docs/mesimi-2-appinsights-function.md"

Write-Host "`nRezultati: $script:ok në rregull, $script:bad për t'u bërë." -ForegroundColor Cyan
if ($script:bad -eq 0) { Write-Host "Të gjitha në rregull!" -ForegroundColor Green }
