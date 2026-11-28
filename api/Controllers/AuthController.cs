using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using ParcelHub.Api.Auth;
using ParcelHub.Api.Data;
using ParcelHub.Api.Infrastructure;
using ParcelHub.Api.Models;

namespace ParcelHub.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
public sealed class AuthController(
    UserRepository users,
    TokenService tokens,
    IPasswordHasher<AppUser> hasher) : ControllerBase
{
    // POST /api/v1/auth/login
    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimits.Login)]
    [ProducesResponseType<LoginResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest request)
    {
        var user = await users.GetForLoginAsync(request.Username);

        // ไม่มีผู้ใช้ กับ รหัสผิด ตอบข้อความเดียวกัน — ไม่บอกว่า username ใดมีอยู่จริง
        if (user is null ||
            hasher.VerifyHashedPassword(user, user.PasswordHash, request.Password)
                == PasswordVerificationResult.Failed)
        {
            return Problem(
                statusCode: StatusCodes.Status401Unauthorized,
                title: "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง");
        }

        var (token, expiresIn) = tokens.Create(user);
        return Ok(new LoginResponse(token, expiresIn, user.Role, user.DisplayName));
    }

    // GET /api/v1/auth/me — ข้อมูลผู้ใช้จาก Token
    [HttpGet("me")]
    [Authorize]
    [ProducesResponseType<MeResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public ActionResult<MeResponse> Me() => Ok(new MeResponse(
        int.Parse(User.FindFirst("sub")!.Value),
        User.FindFirst("unique_name")!.Value,
        User.FindFirst("role")!.Value,
        User.Identity!.Name ?? ""));
}
