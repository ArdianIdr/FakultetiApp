using Microsoft.ApplicationInsights.WorkerService;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var builder = FunctionsApplication.CreateBuilder(args);
builder.Services.AddApplicationInsightsTelemetryWorkerService();
builder.Services.ConfigureFunctionsApplicationInsights();
// Lejo log-et e nivelit Information të dërgohen në Application Insights
builder.Logging.Services.Configure<LoggerFilterOptions>(o =>
{
    var rregulla = o.Rules.FirstOrDefault(r => r.ProviderName == "Microsoft.Extensions.Logging.ApplicationInsights.ApplicationInsightsLoggerProvider");
    if (rregulla is not null) o.Rules.Remove(rregulla);
});
builder.Build().Run();