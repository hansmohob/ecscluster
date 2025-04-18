using Microsoft.AspNetCore.Mvc;
using OrderService.Models;

namespace OrderService.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrderController : ControllerBase
{
    private static readonly List<Order> _orders = new();
    private static int _nextId = 1;

    [HttpGet]
    public ActionResult<IEnumerable<Order>> GetAll()
    {
        return Ok(_orders);
    }

    [HttpGet("{id}")]
    public ActionResult<Order> GetById(int id)
    {
        var order = _orders.FirstOrDefault(o => o.Id.Id == id);
        if (order == null)
            return NotFound();
        return Ok(order);
    }

    [HttpGet("user/{userId}")]
    public ActionResult<IEnumerable<Order>> GetByUserId(int userId)
    {
        var orders = _orders.Where(o => o.UserId == userId);
        return Ok(orders);
    }

    [HttpPost]
    public ActionResult<Order> Create(Order order)
    {
        order.Id = _nextId++;
        order.CreatedAt = DateTime.UtcNow;
        order.Status = "Pending";
        order.TotalAmount = order.Items.Sum(item => item.UnitPrice * item.Quantity);
        
        _orders.Add(order);
        return CreatedAtAction(nameof(GetById), new { id = order.Id }, order);
    }

    [HttpPut("{id}/status")]
    public ActionResult UpdateStatus(int id, [FromBody] string status)
    {
        var order = _orders.FirstOrDefault(o => o.Id == id);
        if (order == null)
            return NotFound();

        order.Status = status;
        return Ok(order);
    }
}