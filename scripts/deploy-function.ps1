<#
.SYNOPSIS
  (Mësimi 2) Ngarkon kodin e Azure Function-it (nga dosja functions/) në Azure.

.DESCRIPTION
  Çfarë bën:
    1. dotnet publish: kompilon Function-in në dosje të përkohshme.
    2. Python: e paketon dosjen në një skedar ZIP (host.json duhet të jetë në rrënjë të ZIP-it).
    3. az ... config-zip: ngarkon ZIP-in në Function App.
    4. Liston funksionet e ngarkuara: duhet të shfaqet PerpunoNjoftim.
  Kërkon: dotnet, az, python.

.EXAMPLE
  ./scripts/deploy-function.ps1 -Student ardian -FunctionApp func-ardian-xxxxx
#>
param(
    [Parameter(Mandatory)][string]$Student,        # emri juaj i vogël
    [Parameter(Mandatory)][string]$FunctionApp     # emri i Function App që keni krijuar (func-<emri>-xxxxx)
)
$ErrorActionPreference = "Continue"
$rg = "rg-$Student"
$root = Split-Path $PSScriptRoot -Parent            # rrënja e repos
$out = Join-Path $env:TEMP "fnpub-$Student"         # dosja e përkohshme e kompilimit
Remove-Item $out, "$out.zip" -Recurse -Force -ErrorAction SilentlyContinue   # pastron ngarkimet e vjetra

# 1) Kompilojmë Function-in
dotnet publish (Join-Path $root "functions") -c Release -o $out -v q

# 2) E paketojmë në ZIP me Python (shtegjet me / që Linux t'i kuptojë)
python -c "import zipfile,os,sys; o=sys.argv[1]; z=zipfile.ZipFile(o+'.zip','w',zipfile.ZIP_DEFLATED); [z.write(os.path.join(r,f),os.path.relpath(os.path.join(r,f),o).replace(os.sep,'/')) for r,_,fs in os.walk(o) for f in fs]" $out

# 3) E ngarkojmë në Azure
az functionapp deployment source config-zip -g $rg -n $FunctionApp --src "$out.zip" -o none

# 4) Kontrollojmë që Function u regjistrua
az functionapp function list -g $rg -n $FunctionApp --query "[].name" -o tsv
