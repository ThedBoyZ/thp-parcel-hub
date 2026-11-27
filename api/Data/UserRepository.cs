using System.Data;
using Dapper;
using ParcelHub.Api.Models;

namespace ParcelHub.Api.Data;

public sealed class UserRepository(SqlConnectionFactory db)
{
    public async Task<AppUser?> GetForLoginAsync(string username)
    {
        using var conn = db.Create();

        return await conn.QuerySingleOrDefaultAsync<AppUser>(
            "dbo.sp_GetUserForLogin",
            new { Username = username },
            commandType: CommandType.StoredProcedure);
    }
}
