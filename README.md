# Fakulteti i Informatikës – Aplikacion demo në Azure

ASP.NET Core MVC (.NET 10) me: **Azure SQL** (studentët), **PostgreSQL** (njoftimet), **Blob Storage** (dokumentet), **Key Vault** (sekretet) dhe **App Service** (hosting).

> **Udhëzuesi i plotë (arkitektura, burimet, deploy, detyra): [docs/udhezues.md](docs/udhezues.md)**

**Të dhënat e klasës (databazat, fjalëkalimet):** [docs/te-dhenat-e-klases.md](docs/te-dhenat-e-klases.md)

## Hapat për studentin

1. **Fork** këtë repo në GitHub-in tuaj.
2. Hyni në Azure CLI:
   ```powershell
   az login --tenant e7dd866d-a284-43a6-90aa-9aad6684a2f0
   az account set --subscription 9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb
   ```
3. Krijoni web app-in (zëvendësoni `emri` me emrin tuaj, p.sh. `ardian`):
   ```powershell
   ./scripts/setup.ps1 -Student emri
   ```
   Në fund shfaqet `APP_NAME`. Shënojeni dhe njoftoni profesorin që të ekzekutojë `provision-student.ps1` për ju.
4. Profesori ju jep `AZURE_CLIENT_ID` (pasi i tregoni emrin e forkut tuaj).
5. Në GitHub: **Settings → Secrets and variables → Actions → New repository secret**, shtoni:
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` (`e7dd866d-a284-43a6-90aa-9aad6684a2f0`), `AZURE_SUBSCRIPTION_ID` (`9f0f210c-952d-4f87-a34a-0f7c1f6a3dcb`), `APP_NAME`.
6. **Actions → Deploy në Azure → Run workflow** (ose bëni një `git push`).
7. Hapni `https://<APP_NAME>.azurewebsites.net`.

## Si funksionon
- `setup.ps1` ruan connection strings në **Key Vault**. App Service lexon me Managed Identity përmes `@Microsoft.KeyVault(...)`, pa fjalëkalime në kod.
- GitHub Actions hyn në Azure me **OIDC** (pa fjalëkalim), me një federated credential vetëm për forkun tuaj.

## Mësimi 2: Application Insights, Queue dhe Function

Udhëzues hap pas hapi me komanda dhe detyra: [docs/mesimi-2-appinsights-function.md](docs/mesimi-2-appinsights-function.md)

## Për profesorin
Burimet e përbashkëta (SQL server, PostgreSQL server, Key Vault, Storage) jetojnë në `rg-shared`; çdo student ka databazën, container-in dhe sekretet e veta.
```powershell
./scripts/setup-shared.ps1                         # një herë
./scripts/setup.ps1 -Student ardian                # web app në rg-ardian (e bën studenti)
./scripts/provision-student.ps1 -Student ardian    # databazat, sekretet dhe lejet (profesori)
./scripts/new-student-identity.ps1 -Student ardian -GitHubRepo "ardian-gh/FakultetiApp"
./scripts/cleanup.ps1 -Student ardian -StopOnly    # ndalon PostgreSQL
./scripts/cleanup.ps1 -Student ardian              # fshin burimet e studentit
```
Studentët kanë Contributor vetëm në `rg-<emri>`, pra nuk kanë qasje në `rg-shared`. Web app-i lexon vetëm tre sekretet e veta (leje për secret, jo për gjithë vault-in).
Kujdes: connection strings përdorin admin-in e serverit të përbashkët, kështu që kodi i një studenti teknikisht mund të prekë databazat e të tjerëve. Është e pranueshme për demo, jo për prodhim.
Kosto: SQL ka kufi falas (10 databaza për abonim), App Service F1 është falas, PostgreSQL B1ms nuk ka nivel falas të përhershëm, Key Vault dhe Storage kushtojnë shumë pak.
Lokalisht: `dotnet run --project src` (kërkon LocalDB dhe PostgreSQL ose vendosni `ConnectionStrings__*`).

> Shënim për profesorin: herën e parë në subscription duhet regjistruar `Microsoft.OperationalInsights`, `microsoft.insights` dhe `Microsoft.App` (`az provider register -n <emri>`).
