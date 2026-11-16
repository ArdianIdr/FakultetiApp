$SubscriptionId = "9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb"
$TenantId       = "e7dd866d-a284-43a6-90aa-9aad6684a2f0"
$SharedRg       = "rg-shared"
$Admin          = "dbadmin"

function Run { & $args[0] $args[1..($args.Length-1)]; if ($LASTEXITCODE -ne 0) { throw "Dështoi: $($args -join ' ')" } }
function Hash5($text) {
    $md5 = [Security.Cryptography.MD5]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($text))
    ([BitConverter]::ToString($md5) -replace '-', '').Substring(0, 5).ToLower()
}
function NewPassword { (-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })) + "aA1" }
function Clean($name) { $name.ToLower() -replace '[^a-z0-9]', '' }

# emrat e burimeve të përbashkëta (të qëndrueshëm)
$sh = Hash5 "$SubscriptionId-shared"
$SharedKv  = "kv-fakulteti-$sh"
$SharedSql = "sql-fakulteti-$sh"
$SharedPg  = "psql-fakulteti-$sh"
$SharedStg = "stfakulteti$sh"
