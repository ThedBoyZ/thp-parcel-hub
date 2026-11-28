using System.Threading.RateLimiting;

namespace ParcelHub.Api.Infrastructure;

// จำกัดจำนวนครั้งต่อนาทีแยกตาม IP (Fixed Window) — เกินกำหนดตอบ 429 + Retry-After
//   Public: ค้นพัสดุโดยไม่ต้อง Login (กันการไล่เดาเลขพัสดุ)
//   Login:  กันการเดารหัสผ่าน (Brute force)
public static class RateLimits
{
    public const string Public = "public";
    public const string Login = "login";

    public static IServiceCollection AddApiRateLimits(this IServiceCollection services)
    {
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            options.OnRejected = async (context, _) =>
            {
                var http = context.HttpContext;

                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
                    http.Response.Headers.RetryAfter = ((int)retryAfter.TotalSeconds).ToString();

                await http.RequestServices.GetRequiredService<IProblemDetailsService>().WriteAsync(new()
                {
                    HttpContext = http,
                    ProblemDetails =
                    {
                        Status = StatusCodes.Status429TooManyRequests,
                        Title = "เรียกใช้งานถี่เกินกำหนด กรุณารอสักครู่แล้วลองใหม่",
                    },
                });
            };

            options.AddPolicy(Public, http => PerIp(http, permitLimit: 30));
            options.AddPolicy(Login, http => PerIp(http, permitLimit: 5));
        });

        return services;
    }

    private static RateLimitPartition<string> PerIp(HttpContext http, int permitLimit) =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = permitLimit,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            });
}
