<#
.SYNOPSIS
  Vlerat e përbashkëta dhe funksionet ndihmëse. NUK ekzekutohet vetë: e ngarkojnë skriptat e tjera.

.DESCRIPTION
  Çdo skript fillon me:  . "$PSScriptRoot/common.ps1"
  (pika në fillim do të thotë "ngarko këtë skedar këtu").
#>

# --- Vlerat e klasës ---
$SubscriptionId = "9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb"   # subscription i profesorit
$TenantId       = "e7dd866d-a284-43a6-90aa-9aad6684a2f0"   # tenant (organizata në Azure/Entra ID)
$SharedRg       = "rg-shared"                              # grupi me burimet e përbashkëta
$Admin          = "dbadmin"                                # përdoruesi admin i serverëve SQL dhe PostgreSQL

# --- Funksione ndihmëse ---

# Run: ekzekuton një komandë dhe ndalon nëse dështon (kodi i daljes nuk është 0)
function Run { $ErrorActionPreference = "Continue"; & $args[0] $args[1..($args.Length-1)]; if ($LASTEXITCODE -ne 0) { throw "Dështoi: $($args -join ' ')" } }

# Hash5: nga një tekst nxjerr 5 shkronja/numra gjithmonë të njëjtë (për emra unikë, p.sh. app-ardian-1a2b3)
function Hash5($text) {
    $md5 = [Security.Cryptography.MD5]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($text))
    ([BitConverter]::ToString($md5) -replace '-', '').Substring(0, 5).ToLower()
}

# NewPassword: gjeneron fjalëkalim të rastësishëm (përdoret nga profesori)
function NewPassword { (-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })) + "aA1" }

# Clean: emrin e kthen në shkronja të vogla pa karaktere speciale (Azure nuk i pranon në emra)
function Clean($name) { $name.ToLower() -replace '[^a-z0-9]', '' }

# --- Burimet e përbashkëta ekzistuese (rg-shared) ---
# Rajonet: SQL swedencentral, PostgreSQL uksouth, të tjerat eastus
$SharedKv  = "kv-fakulteti-f7k2q"      # Key Vault i profesorit (kopje rezervë)
$SharedSql = "sql-fakulteti-zmusi"     # SQL server
$SharedPg  = "psql-fakulteti-qzpml"    # PostgreSQL server
$SharedStg = "stfakultetif7k2q"        # Storage account (Blob)
