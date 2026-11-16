# Fakulteti i Informatikës – Aplikacion demo në Azure

ASP.NET Core MVC (.NET 8) me: **Azure SQL** (studentët), **PostgreSQL** (njoftimet), **Blob Storage** (dokumentet), **Key Vault** (sekretet) dhe **App Service** (hosting).

## Hapat për studentin

1. **Fork** këtë repo në GitHub-in tuaj.
2. Hyni në Azure CLI:
   ```powershell
   az login --tenant e7dd866d-a284-43a6-90aa-9aad6684a2f0
   az account set --subscription 9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb
   ```
3. Krijoni burimet (zëvendësoni `emri` me emrin tuaj, p.sh. `ardian`):
   ```powershell
   ./scripts/setup.ps1 -Student emri
   ```
   Në fund shfaqet `APP_NAME`. Shënojeni.
4. Mësuesi ju jep `AZURE_CLIENT_ID` (pasi i tregoni emrin e forkut tuaj).
5. Në GitHub: **Settings → Secrets and variables → Actions → New repository secret**, shtoni:
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` (`e7dd866d-a284-43a6-90aa-9aad6684a2f0`), `AZURE_SUBSCRIPTION_ID` (`9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb`), `APP_NAME`.
6. **Actions → Deploy në Azure → Run workflow** (ose bëni një `git push`).
7. Hapni `https://<APP_NAME>.azurewebsites.net`.

## Si funksionon
- `setup.ps1` ruan connection strings në **Key Vault**. App Service lexon me Managed Identity përmes `@Microsoft.KeyVault(...)`, pa fjalëkalime në kod.
- GitHub Actions hyn në Azure me **OIDC** (pa fjalëkalim), me një federated credential vetëm për forkun tuaj.

## Për mësuesin
```powershell
./scripts/setup.ps1 -Student ardian
./scripts/new-student-identity.ps1 -Student ardian -GitHubRepo "ardian-gh/FakultetiApp"
./scripts/cleanup.ps1 -Student ardian -StopOnly   # ndalon PostgreSQL
./scripts/cleanup.ps1 -Student ardian             # fshin burimet
```
Kujdes: SQL ka kufi falas (10 databaza për abonim, pa kosto brenda kufirit), App Service F1 është falas, ndërsa PostgreSQL B1ms nuk ka nivel falas të përhershëm (vetëm 12 muaj falas për llogari të reja). Key Vault dhe Storage kushtojnë shumë pak.

Lokalisht: `dotnet run --project src` (kërkon LocalDB dhe PostgreSQL ose vendosni `ConnectionStrings__*`).
