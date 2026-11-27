using Microsoft.Data.SqlClient;

namespace ParcelHub.Api.Data;

// สร้าง Connection ต่อ 1 งาน (SqlClient ทำ Connection Pooling ให้)
public sealed class SqlConnectionFactory(IConfiguration config)
{
    private readonly string _connectionString =
        config.GetConnectionString("ParcelHub")
        ?? throw new InvalidOperationException("ไม่พบ ConnectionStrings:ParcelHub ใน appsettings");

    public SqlConnection Create() => new(_connectionString);
}
