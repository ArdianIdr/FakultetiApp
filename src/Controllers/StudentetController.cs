using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using FakultetiApp.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FakultetiApp.Controllers;

public class StudentetController(SqlDbContext db, BlobContainerClient blobs) : Controller
{
    public async Task<IActionResult> Index() =>
        View(await db.Studentet.OrderBy(s => s.Mbiemri).ToListAsync());

    public IActionResult Krijo() => View();

    [HttpPost]
    public async Task<IActionResult> Krijo(Student s, IFormFile? dokumenti)
    {
        if (!ModelState.IsValid) return View(s);
        if (dokumenti is { Length: > 0 })
        {
            var emri = $"{Guid.NewGuid():N}-{Path.GetFileName(dokumenti.FileName)}";
            var blob = blobs.GetBlobClient(emri);
            await using var stream = dokumenti.OpenReadStream();
            await blob.UploadAsync(stream, new BlobHttpHeaders { ContentType = dokumenti.ContentType });
            s.DokumentiUrl = blob.Uri.ToString();
        }
        db.Add(s);
        await db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    public async Task<IActionResult> Fshij(int id)
    {
        var s = await db.Studentet.FindAsync(id);
        if (s != null)
        {
            if (s.DokumentiUrl != null)
                await blobs.GetBlobClient(Path.GetFileName(new Uri(s.DokumentiUrl).LocalPath)).DeleteIfExistsAsync();
            db.Remove(s);
            await db.SaveChangesAsync();
        }
        return RedirectToAction(nameof(Index));
    }
}
