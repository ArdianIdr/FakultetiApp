<#
.SYNOPSIS
  Fshin (ose ndalon) burimet e studentit pas mësimit që të mos kushtojnë.
#>
param(
    [Parameter(Mandatory)][string]$Student,
    [switch]$StopOnly,
    [string]$SubscriptionId = "9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb"
)
$s = $Student.ToLower() -replace '[^a-z0-9]', ''
$rg = "rg-$s"
az account set --subscription $SubscriptionId
if ($StopOnly) {
    # Ndalon PostgreSQL (kostoja kryesore); riniset automatikisht pas 7 ditësh
    $pg = az postgres flexible-server list -g $rg --query "[0].name" -o tsv
    az postgres flexible-server stop -g $rg -n $pg
} else {
    # Fshin vetëm burimet brenda grupit, grupin e mban
    $ids = az resource list -g $rg --query "[].id" -o tsv
    if ($ids) { az resource delete --ids $ids.Split("`n") }
}
