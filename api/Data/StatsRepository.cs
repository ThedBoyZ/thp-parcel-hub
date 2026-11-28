using System.Data;
using Dapper;
using ParcelHub.Api.Models;

namespace ParcelHub.Api.Data;

// ข้อมูลหน้า Dashboard — กรองตามช่วงวันที่รับฝาก (ใช้ IX_Parcel_AcceptedAt)
public sealed class StatsRepository(SqlConnectionFactory db)
{
    public async Task<IReadOnlyList<MonthlySummary>> GetMonthlySummaryAsync(DateOnly from, DateOnly to)
    {
        using var conn = db.Create();
        var rows = await conn.QueryAsync<MonthlySummary>(
            "dbo.sp_GetMonthlySummary", Range(from, to),
            commandType: CommandType.StoredProcedure);
        return rows.AsList();
    }

    public async Task<IReadOnlyList<StatusCount>> GetStatusSummaryAsync(DateOnly from, DateOnly to)
    {
        using var conn = db.Create();
        var rows = await conn.QueryAsync<StatusCount>(
            "dbo.sp_GetStatusSummary", Range(from, to),
            commandType: CommandType.StoredProcedure);
        return rows.AsList();
    }

    public async Task<IReadOnlyList<BranchDelay>> GetBranchDelaysAsync(DateOnly from, DateOnly to, int top)
    {
        using var conn = db.Create();
        var rows = await conn.QueryAsync<BranchDelay>(
            "dbo.sp_GetBranchDelays",
            new
            {
                FromDate = from.ToDateTime(TimeOnly.MinValue),
                ToDate = to.ToDateTime(TimeOnly.MinValue),
                Top = top,
            },
            commandType: CommandType.StoredProcedure);
        return rows.AsList();
    }

    private static object Range(DateOnly from, DateOnly to) => new
    {
        FromDate = from.ToDateTime(TimeOnly.MinValue),
        ToDate = to.ToDateTime(TimeOnly.MinValue),
    };
}
