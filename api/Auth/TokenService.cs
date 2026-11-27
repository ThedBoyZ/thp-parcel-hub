using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using ParcelHub.Api.Models;

namespace ParcelHub.Api.Auth;

// ออก JWT (HS256) — Claims ไม่มีข้อมูลลับ เพราะ payload อ่านได้ทุกคน แต่แก้ไม่ได้เพราะมีลายเซ็น
public sealed class TokenService(IOptions<JwtOptions> options)
{
    private readonly JwtOptions _jwt = options.Value;
    private readonly JsonWebTokenHandler _handler = new();

    public (string Token, int ExpiresIn) Create(AppUser user)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.Key));
        var expires = DateTime.UtcNow.AddMinutes(_jwt.ExpiresMinutes);

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _jwt.Issuer,
            Audience = _jwt.Audience,
            Expires = expires,
            Subject = new ClaimsIdentity(
            [
                new Claim(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
                new Claim(JwtRegisteredClaimNames.UniqueName, user.Username),
                new Claim("name", user.DisplayName),
                new Claim("role", user.Role),
            ]),
            SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256),
        };

        return (_handler.CreateToken(descriptor), _jwt.ExpiresMinutes * 60);
    }
}
