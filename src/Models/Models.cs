using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace FakultetiApp.Models;

public class Student
{
    public int Id { get; set; }
    [Required(ErrorMessage = "Emri është i detyrueshëm"), Display(Name = "Emri")]
    public string Emri { get; set; } = "";
    [Required(ErrorMessage = "Mbiemri është i detyrueshëm"), Display(Name = "Mbiemri")]
    public string Mbiemri { get; set; } = "";
    [Required, EmailAddress(ErrorMessage = "Email i pavlefshëm")]
    public string Email { get; set; } = "";
    [Display(Name = "Viti i studimit"), Range(1, 5)]
    public int Viti { get; set; } = 1;
    [Display(Name = "Dokumenti")]
    public string? DokumentiUrl { get; set; }
}

public class Njoftim
{
    public int Id { get; set; }
    [Required(ErrorMessage = "Titulli është i detyrueshëm"), Display(Name = "Titulli")]
    public string Titulli { get; set; } = "";
    [Required, Display(Name = "Përmbajtja")]
    public string Permbajtja { get; set; } = "";
    public DateTime Data { get; set; } = DateTime.UtcNow;
}

public class SqlDbContext(DbContextOptions<SqlDbContext> o) : DbContext(o)
{
    public DbSet<Student> Studentet => Set<Student>();
}

public class PgDbContext(DbContextOptions<PgDbContext> o) : DbContext(o)
{
    public DbSet<Njoftim> Njoftimet => Set<Njoftim>();
}
