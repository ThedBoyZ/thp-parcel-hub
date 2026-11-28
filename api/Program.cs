using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using ParcelHub.Api.Auth;
using ParcelHub.Api.Data;
using ParcelHub.Api.Infrastructure;
using ParcelHub.Api.Models;

var builder = WebApplication.CreateBuilder(args);

// ---- Services --------------------------------------------------------
builder.Services.AddControllers();
builder.Services.AddProblemDetails();       // Error ทุกตัวตอบเป็น ProblemDetails (RFC 9457)

builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<UserRepository>();
builder.Services.AddScoped<ParcelRepository>();
builder.Services.AddScoped<StatsRepository>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<IPasswordHasher<AppUser>, PasswordHasher<AppUser>>();

builder.Services.AddApiRateLimits();

// ---- CORS: อนุญาตเฉพาะ Origin ของหน้าเว็บที่กำหนดใน appsettings (Cors:Origins) ----
var corsOrigins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? [];
builder.Services.AddCors(options => options.AddDefaultPolicy(policy => policy
    .WithOrigins(corsOrigins)
    .AllowAnyHeader()
    .AllowAnyMethod()));

// ---- Authentication: JWT Bearer ----------------------------------------
var jwtSection = builder.Configuration.GetSection(JwtOptions.SectionName);
builder.Services.Configure<JwtOptions>(jwtSection);
var jwt = jwtSection.Get<JwtOptions>() ?? new JwtOptions();

if (jwt.Key.Length < 32)
    throw new InvalidOperationException("Jwt:Key ต้องยาวอย่างน้อย 32 ตัวอักษร (ตั้งใน appsettings.Development.json)");

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30),
            NameClaimType = "name",
            RoleClaimType = "role",
        };
    });

// ---- Authorization: Role-based แบบลำดับขั้น ------------------------------
builder.Services.AddAuthorizationBuilder()
    .AddPolicy(Policies.StaffUp, p => p.RequireRole(Roles.Staff, Roles.DataSteward, Roles.Admin))
    .AddPolicy(Policies.StewardUp, p => p.RequireRole(Roles.DataSteward, Roles.Admin))
    .AddPolicy(Policies.AdminOnly, p => p.RequireRole(Roles.Admin));

// ---- Swagger (มีปุ่ม Authorize สำหรับใส่ Token) -----------------------------
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Parcel Data Service Hub API",
        Version = "v1",
        Description = "ข้อมูลจำลองเพื่อการนำเสนอ (Simulated data) — ไม่ใช่ระบบจริงของ บริษัท ไปรษณีย์ไทย จำกัด",
    });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "วาง Token ที่ได้จาก POST /api/v1/auth/login (ไม่ต้องพิมพ์คำว่า Bearer)",
    });
    c.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", document)] = [],
    });
});

var app = builder.Build();

// ---- Pipeline (Authentication ต้องมาก่อน Authorization) --------------------
app.UseExceptionHandler();
app.UseStatusCodePages();
app.UseHttpsRedirection();        // ก่อน Swagger เพื่อให้ทุกหน้าเด้งไป https

// Production เปิด Swagger ได้ด้วย "Swagger:Enabled": true (ใช้กับเครื่อง Demo)
if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();                    // ก่อน Authentication: Preflight (OPTIONS) ไม่มี Token
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapControllers();

app.Run();
