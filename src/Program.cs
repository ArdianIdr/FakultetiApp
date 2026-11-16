using Azure.Storage.Blobs;
using Azure.Storage.Queues;
using FakultetiApp.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllersWithViews();
// Lexon APPLICATIONINSIGHTS_CONNECTION_STRING nga App Service (nëse mungon, nuk dërgon telemetri)
builder.Services.AddApplicationInsightsTelemetry();

// Vlerat vijnë nga App Service (të lidhura me Key Vault): ConnectionStrings__Sql, __Postgres, __Storage
var cs = builder.Configuration.GetSection("ConnectionStrings");
builder.Services.AddDbContext<SqlDbContext>(o => o.UseSqlServer(cs["Sql"] ?? "Server=(localdb)\\mssqllocaldb;Database=Fakulteti;Trusted_Connection=True"));
builder.Services.AddDbContext<PgDbContext>(o => o.UseNpgsql(cs["Postgres"] ?? "Host=localhost;Database=fakulteti;Username=postgres;Password=postgres"));
builder.Services.AddSingleton(_ => new BlobContainerClient(cs["Storage"] ?? "UseDevelopmentStorage=true", builder.Configuration["Blob:Container"] ?? "dokumentet"));
builder.Services.AddSingleton(_ => new QueueClient(cs["Queue"] ?? cs["Storage"] ?? "UseDevelopmentStorage=true", "njoftime"));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    try
    {
        scope.ServiceProvider.GetRequiredService<SqlDbContext>().Database.EnsureCreated();
        scope.ServiceProvider.GetRequiredService<PgDbContext>().Database.EnsureCreated();
        scope.ServiceProvider.GetRequiredService<BlobContainerClient>().CreateIfNotExists(Azure.Storage.Blobs.Models.PublicAccessType.Blob);
        scope.ServiceProvider.GetRequiredService<QueueClient>().CreateIfNotExists();
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Inicializimi i burimeve dështoi");
    }
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
}
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();
app.MapControllerRoute("default", "{controller=Home}/{action=Index}/{id?}");
app.Run();
