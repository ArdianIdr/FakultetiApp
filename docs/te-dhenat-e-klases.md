# Të dhënat e klasës (demo)

> Vetëm për demonstrim në klasë. Fjalëkalimet ndërrohen pas mësimit; firewall-et janë të hapura.

## Serverët e përbashkët

| Burimi | Vlera |
|---|---|
| SQL server | `sql-fakulteti-zmusi.database.windows.net` |
| SQL user / fjalëkalimi | `dbadmin` / `Sql!81dbe3dd8a874537` |
| PostgreSQL server | `psql-fakulteti-qzpml.postgres.database.azure.com` |
| PostgreSQL user / fjalëkalimi | `dbadmin` / `Pg!94ddacf2a9e244f7` |
| Storage account | `stfakultetif7k2q` |
| Key Vault | `kv-fakulteti-f7k2q` |

## Databazat e secilit student

| Studenti | SQL db | PostgreSQL db | Blob container |
|---|---|---|---|
| ardian | `db-ardian` | `ardian` | `dokumentet-ardian` |
| arjeta | `db-arjeta` | `arjeta` | `dokumentet-arjeta` |
| clirim | `db-clirim` | `clirim` | `dokumentet-clirim` |
| faton | `db-faton` | `faton` | `dokumentet-faton` |
| shefki | `db-shefki` | `shefki` | `dokumentet-shefki` |

## Connection string-ët (zëvendësoni `<emri>`)

```
Sql:      Server=tcp:sql-fakulteti-zmusi.database.windows.net,1433;Database=db-<emri>;User ID=dbadmin;Password=Sql!81dbe3dd8a874537;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;
Postgres: Host=psql-fakulteti-qzpml.postgres.database.azure.com;Port=5432;Database=<emri>;Username=dbadmin;Password=Pg!94ddacf2a9e244f7;SSL Mode=Require;Trust Server Certificate=true
```

## Verifikimi i të dhënave

- **SQL:** Portal → `rg-shared` → `sql-fakulteti-zmusi` → `db-<emri>` → **Query editor** → hyrje me `dbadmin`; pastaj `SELECT * FROM Studentet;`
- **PostgreSQL:** `psql "host=psql-fakulteti-qzpml.postgres.database.azure.com dbname=<emri> user=dbadmin sslmode=require"`; pastaj `SELECT * FROM "Njoftimet";`
- **Blob:** Portal → `stfakultetif7k2q` → Containers → `dokumentet-<emri>`

## Si i përdorni (zgjidhni një)

**A) Drejtpërdrejt si App settings** (më e thjeshta). Pas `setup.ps1`:
```powershell
$s = "emri"; $rg = "rg-$s"
$app = az webapp list -g $rg --query "[0].name" -o tsv
@{
  "ConnectionStrings__Sql"      = "<Sql nga lart>"
  "ConnectionStrings__Postgres" = "<Postgres nga lart>"
} | ConvertTo-Json | Set-Content db.json
az webapp config appsettings set -g $rg -n $app --settings "@db.json"
Remove-Item db.json
```
Verifikim: Portal → App Service → *Environment variables*.

**B) Me Key Vault:** `setup.ps1` vendos tashmë referencat `@Microsoft.KeyVault(...)`. Sekretet `<emri>-SqlConnection`, `<emri>-PostgresConnection`, `<emri>-StorageConnection` ekzistojnë në `kv-fakulteti-f7k2q`. Profesori ekzekuton `./scripts/provision-student.ps1 -Student <emri>` përsëri pasi të ekzistojë web app-i, për t'i dhënë lejen identitetit të tij. Verifikim: *Environment variables* → statusi *Resolved*.
