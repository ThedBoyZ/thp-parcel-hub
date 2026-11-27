using System.ComponentModel.DataAnnotations;

namespace ParcelHub.Api.Models;

// แถวจาก sp_GetUserForLogin (ใช้ภายใน API เท่านั้น ไม่ส่งออกไปกับ Response)
public sealed class AppUser
{
    public int UserId { get; init; }
    public string Username { get; init; } = "";
    public string PasswordHash { get; init; } = "";
    public string Role { get; init; } = "";
    public string DisplayName { get; init; } = "";
}

public sealed record LoginRequest(
    [Required, MaxLength(50)] string Username,
    [Required, MaxLength(100)] string Password);

public sealed record LoginResponse(
    string Token,
    int ExpiresIn,          // วินาที
    string Role,
    string DisplayName);

public sealed record MeResponse(
    int UserId,
    string Username,
    string Role,
    string DisplayName);
