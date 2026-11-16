<#
.SYNOPSIS
  (Për profesorin) Krijon app registration + federated credential për forkun e studentit,
  e lejon vetëm në rg-<student> dhe printon 4 vlerat për GitHub Secrets.
.EXAMPLE
  ./scripts/new-student-identity.ps1 -Student ardian -GitHubRepo "ardian123/FakultetiApp"
#>
param(
    [Parameter(Mandatory)][string]$Student,
    [Parameter(Mandatory)][string]$GitHubRepo,   # owner/repo i forkut
    [string]$Branch = "main",
    [string]$SubscriptionId = "9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb",
    [string]$TenantId = "e7dd866d-a284-43a6-90aa-9aad6684a2f0"
)
$ErrorActionPreference = "Stop"
$s = $Student.ToLower() -replace '[^a-z0-9]', ''
$rg = "rg-$s"
az account set --subscription $SubscriptionId

$appId = az ad app create --display-name "gh-deploy-$s" --query appId -o tsv
az ad sp create --id $appId -o none
az role assignment create --assignee $appId --role Contributor `
    --scope "/subscriptions/$SubscriptionId/resourceGroups/$rg" -o none

$cred = @{
    name      = "github-$s"
    issuer    = "https://token.actions.githubusercontent.com"
    subject   = "repo:${GitHubRepo}:ref:refs/heads/$Branch"
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Compress
$tmp = New-TemporaryFile
Set-Content $tmp $cred
az ad app federated-credential create --id $appId --parameters "@$tmp" -o none
Remove-Item $tmp

$app = az webapp list -g $rg --query "[0].name" -o tsv
Write-Host "`nGitHub Secrets për $GitHubRepo :" -ForegroundColor Green
Write-Host "AZURE_CLIENT_ID       = $appId"
Write-Host "AZURE_TENANT_ID       = $TenantId"
Write-Host "AZURE_SUBSCRIPTION_ID = $SubscriptionId"
Write-Host "APP_NAME              = $app"
