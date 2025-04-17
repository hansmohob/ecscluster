using Microsoft.AspNetCore.Mvc;
usiusing UserService.Models;

namespace UserService.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UserController : ControllerBase
{
    private static readonlonly List<User> _users = new()
    {
        new User 
        { 
            Id = 1, 
            Username = "john.doe", 
            Email = "john@example.com",
            FirstName = "John",
            LastName = "Doe"
        },
        new User 
        { 
            Id = 2, 
            Username = "jane.smith", 
            Email = "jane@example.com",
            FirstName = "Jane",
            LastName = "Smith"
        }
    };

    private static readonly Dictionary<int, UserProfile> _profiles = new()
    {
        { 1, new UserProfile() },
        { 2, new UserProfile() }
    };

    [HttpGet]
    public ActionResult<IEnumerable<User>> GetAll()
    {
        return Ok(_users);
    }

    [HttpGet("{id}")]
    public ActionResult<User> GetById(int id)
    {
        var user = _users.FirstOrDefault(u => u.Id == id);
        if (user == null)
            return NotFound();
        return Ok(user);
    }

    [HttpPost]
    public ActionResult<User> Create(User user)
    {
        user.Id = _users.Max(u => u.Id) + 1;
        user.CreatedAt = DateTime.UtcNow;
        _users.Add(user);
        _profiles[user.Id] = new UserProfile();
        return CreatedAtAction(nameof(GetById), new { id = user.Id }, user);
    }

    [HttpGet("{id}/profile")]
    public ActionResult<UserProfile> GetProfile(int id)
    {
        if (!_profiles.ContainsKey(id))
            return NotFound();
        return Ok(_profiles[id]);
    }

    [HttpPut("{id}/profile")]
    public ActionResult UpdateProfile(int id, UserProfile profile)
    {
        if (!_profiles.ContainsKey(id))
            return NotFound();
        
        _profiles[id] = profile;
        return Ok(profile);
    }

    [HttpGet("search")]
    public ActionResult<IEnumerable<User>> Search([FromQuery] string? email, [FromQuery] string? username)
    {
        var query = _users.AsQueryable();

        if (!string.IsNullOrEmpty(email))
            query = query.Where(u => u.Email.Contains(email));

        if (!string.IsNullOrEmpty(username))
            query = query.Where(u => u.Username.Contains(username));

        return Ok(query.ToList());
    }
}