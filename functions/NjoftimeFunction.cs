using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace FakultetiFunctions;

public class NjoftimeFunction(ILogger<NjoftimeFunction> logger)
{
    // Ekzekutohet automatikisht sa herë që vjen mesazh i ri në radhën "njoftime"
    [Function("PerpunoNjoftim")]
    public void Run([QueueTrigger("njoftime", Connection = "QueueConnection")] string mesazhi)
    {
        logger.LogInformation("U pranua njoftimi nga radha: {Mesazhi}", mesazhi);
    }
}