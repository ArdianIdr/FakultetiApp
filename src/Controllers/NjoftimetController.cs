using FakultetiApp.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FakultetiApp.Controllers;

public class NjoftimetController(PgDbContext db) : Controller
{
    public async Task<IActionResult> Index() =>
        View(await db.Njoftimet.OrderByDescending(n => n.Data).ToListAsync());

    public IActionResult Krijo() => View();

    [HttpPost]
    public async Task<IActionResult> Krijo(Njoftim n)
    {
        if (!ModelState.IsValid) return View(n);
        n.Data = DateTime.UtcNow;
        db.Add(n);
        await db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    public async Task<IActionResult> Fshij(int id)
    {
        var n = await db.Njoftimet.FindAsync(id);
        if (n != null) { db.Remove(n); await db.SaveChangesAsync(); }
        return RedirectToAction(nameof(Index));
    }
}
