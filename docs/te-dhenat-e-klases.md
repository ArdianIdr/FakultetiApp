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

## Çelësi i Storage
Jepet nga profesori gojarisht/në chat (GitHub nuk lejon çelësa Azure në repo).

`<çelësi-i-storage>`

## Vlerat për GitHub Secrets (hapi 5)

Te forku juaj: Settings → Secrets and variables → Actions → New repository secret.

| Secret | Vlera |
|---|---|
| `AZURE_TENANT_ID` | `e7dd866d-a284-43a6-90aa-9aad6684a2f0` |
| `AZURE_SUBSCRIPTION_ID` | `9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb` |
| `APP_NAME` | emri që printoi `setup.ps1` (ose `kontrollo.ps1`) |
| `AZURE_CLIENT_ID` | shih tabelën më poshtë (secili ka të vetin) |

| Studenti | GitHub | `AZURE_CLIENT_ID` |
|---|---|---|
| faton | ftnFazliu | `67fc75d8-55ec-4c7e-b569-147e8e6bc444` |
| arjeta | arjetaademi | `b1af6a10-4975-4a5f-873e-ff3b292d6c8e` |
| shefki | shefkilika | `62878083-372f-46d3-b56b-5e4ea8634683` |
| clirim | clirimmm | `201b117d-f78b-4667-a1be-b67a071d1b6a` |
| ardian | ArdianIdr | `95792102-cb54-4e45-8f18-b0755d0fe269` |

Këto ID nuk janë fjalëkalime. Forku duhet të quhet saktësisht `FakultetiApp` dhe workflow-t punojnë vetëm nga dega `main`.

## Key Vault-i juaj (secili krijon të vetin)

Profesori ju ka dhënë në g-<emri> rolet **Key Vault Administrator** dhe **User Access Administrator**, që të krijoni Key Vault-in dhe t'i jepni web app-it leje. Pasi të keni bërë setup.ps1 (web app ekziston):

```powershell
./scripts/keyvault-student.ps1 -Student emri `
  -SqlPassword "Sql!81dbe3dd8a874537" `
  -PgPassword "Pg!94ddacf2a9e244f7" `
  -StorageKey "<çelësi-i-storage>"
```

Skripti: krijon kv-<emri>-xxxxx në g-<emri>, ruan sekretet SqlConnection, PostgresConnection, StorageConnection, i jep identitetit të web app-it rolin *Key Vault Secrets User* dhe vendos referencat @Microsoft.KeyVault(...). Rolet RBAC mund të vonojnë 1–5 minuta; skripti pret vetë.

**Verifikim në Portal:** g-<emri> → Key Vault → *Objects → Secrets* (3 sekrete); web app → *Environment variables* → statusi **Resolved**; Key Vault → *Access control (IAM)* → web app-i me *Key Vault Secrets User*.