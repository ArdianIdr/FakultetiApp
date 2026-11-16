# Mësimi 2 — Application Insights, Storage Queue dhe Azure Function

Ekzekuto komandat **një nga një** në PowerShell (pasi je loguar me `az login`). Çdo student krijon burimet **në grupin e vet** `rg-<emri>`.

## 0. Variablat

```powershell
$s   = "emri"                      # p.sh. "arjeta"
$rg  = "rg-$s"
$loc = "eastus"
$sfx = -join ((1..5) | % { 'abcdefghijklmnopqrstuvwxyz0123456789'[(Get-Random -Max 36)] })
$app = az webapp list -g $rg --query "[0].name" -o tsv   # web app-i nga mësimi 1
```

## 1. Application Insights (monitorimi)

```powershell
az monitor log-analytics workspace create -g $rg -n "log-$s" -l $loc
az monitor app-insights component create -g $rg -a "appi-$s" -l $loc --workspace "log-$s" --kind web
$ai = az monitor app-insights component show -g $rg -a "appi-$s" --query connectionString -o tsv
```

Lidhe me web app-in (përdor skedar JSON, që karakteret `;` të mos prishin komandën):

```powershell
@{ APPLICATIONINSIGHTS_CONNECTION_STRING = $ai } | ConvertTo-Json | Set-Content ai.json
az webapp config appsettings set -g $rg -n $app --settings "@ai.json"
Remove-Item ai.json
```

**Kontrollo:** hap faqen e web app-it disa herë, pastaj në Portal → `appi-<emri>` → *Live metrics* / *Transaction search*.

## 2. Storage Account + Queue (radha e mesazheve)

```powershell
$st = "stfn$s$sfx"                 # vetëm shkronja të vogla/numra, max 24 karaktere
az storage account create -g $rg -n $st -l $loc --sku Standard_LRS --allow-blob-public-access false
$conn = az storage account show-connection-string -g $rg -n $st --query connectionString -o tsv
az storage queue create --name njoftime --connection-string $conn
```

Web app-i do të dërgojë mesazh në radhë sa herë shtohet një student:

```powershell
@{ "ConnectionStrings__Queue" = $conn } | ConvertTo-Json | Set-Content q.json
az webapp config appsettings set -g $rg -n $app --settings "@q.json"
Remove-Item q.json
```

## 3. Azure Function (Flex Consumption, .NET 10)

```powershell
az provider register -n Microsoft.App          # vetëm herën e parë
$fn = "func-$s-$sfx"
az functionapp create -g $rg -n $fn --storage-account $st --flexconsumption-location $loc --runtime dotnet-isolated --runtime-version 10 --instance-memory 512 --maximum-instance-count 40
@{ QueueConnection = $conn; APPLICATIONINSIGHTS_CONNECTION_STRING = $ai } | ConvertTo-Json | Set-Content fn.json
az functionapp config appsettings set -g $rg -n $fn --settings "@fn.json"
Remove-Item fn.json
```

Ngarko kodin e Function-it (nga `functions/` në repo-n tënd):

```powershell
./scripts/deploy-function.ps1 -Student $s -FunctionApp $fn
```

Duhet të shfaqet `PerpunoNjoftim`.

## 4. Provo gjithçka

1. Hap web app-in → **Studentët → Shto** një student.
2. Prit ~1 minutë. Në Portal → `appi-<emri>` → *Logs*:

```kusto
traces | where message has "U pranua" | order by timestamp desc
```

Rrjedha: **Web app → Queue `njoftime` → Function → Application Insights**.

## Detyra (ushtrim)

1. Në `functions/NjoftimeFunction.cs` ndrysho mesazhin e log-ut, ri-ngarko me `deploy-function.ps1` dhe verifiko.
2. Dërgo mesazh me dorë: `az storage message put -q njoftime --content "Përshëndetje" --connection-string $conn`
3. Në `NjoftimetController` dërgo mesazh në radhë edhe kur shtohet një njoftim.
4. Shkruaj një KQL që numëron sa mesazhe janë procesuar në orën e fundit.
5. *Sfidë:* ruaje `$conn` në Key Vault dhe përdor referencë `@Microsoft.KeyVault(...)`.

## Pastrimi

```powershell
az functionapp delete -g $rg -n $fn
az storage account delete -g $rg -n $st --yes
az monitor app-insights component delete -g $rg -a "appi-$s"
az monitor log-analytics workspace delete -g $rg -n "log-$s" --yes
```