namespace ParcelHub.Api.Auth;

// ตั้งค่าจาก appsettings หัวข้อ "Jwt" · Key อยู่ใน appsettings.Development.json (ไม่ขึ้น Git)
public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    public string Issuer { get; init; } = "";
    public string Audience { get; init; } = "";
    public string Key { get; init; } = "";
    public int ExpiresMinutes { get; init; } = 60;
}
