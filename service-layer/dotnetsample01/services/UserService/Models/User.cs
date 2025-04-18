namespace UserService.Models;

public class User
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class UserProfile
{
    public string PreferredLanguage { get; set; } = "en";
    public string Theme { get; set; } = "light";
    public Dictionary<string, string> Preferences { get; set; } = new();
}