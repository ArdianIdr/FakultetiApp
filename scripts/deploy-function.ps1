param([Parameter(Mandatory)][string]$Student, [Parameter(Mandatory)][string]$FunctionApp)
# Publikon dhe ngarkon Function-in (functions/) në Azure. Kërkon: dotnet, az, python.
$ErrorActionPreference = "Continue"
$rg = "rg-$Student"
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $env:TEMP "fnpub-$Student"
Remove-Item $out, "$out.zip" -Recurse -Force -ErrorAction SilentlyContinue
dotnet publish (Join-Path $root "functions") -c Release -o $out -v q
python -c "import zipfile,os,sys; o=sys.argv[1]; z=zipfile.ZipFile(o+'.zip','w',zipfile.ZIP_DEFLATED); [z.write(os.path.join(r,f),os.path.relpath(os.path.join(r,f),o).replace(os.sep,'/')) for r,_,fs in os.walk(o) for f in fs]" $out
az functionapp deployment source config-zip -g $rg -n $FunctionApp --src "$out.zip" -o none
az functionapp function list -g $rg -n $FunctionApp --query "[].name" -o tsv