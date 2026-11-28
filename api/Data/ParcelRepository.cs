using System.Data;
using Dapper;
using ParcelHub.Api.Models;

namespace ParcelHub.Api.Data;

// ข้อมูลพัสดุ — เรียกผ่าน Stored Procedure และส่งค่าเป็น Parameter เท่านั้น
public sealed class ParcelRepository(SqlConnectionFactory db)
{
    public async Task<ParcelDetail?> GetByTrackingNoAsync(string trackingNo)
    {
        using var conn = db.Create();

        return await conn.QuerySingleOrDefaultAsync<ParcelDetail>(
            "dbo.sp_GetParcelByTrackingNo",
            new { TrackingNo = trackingNo },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<ParcelEvent>> GetEventsAsync(string trackingNo)
    {
        using var conn = db.Create();

        var rows = await conn.QueryAsync<ParcelEvent>(
            "dbo.sp_GetParcelEvents",
            new { TrackingNo = trackingNo },
            commandType: CommandType.StoredProcedure);

        return rows.AsList();
    }

    // ค้นหลายเลข (สูงสุด 10): ใช้ Connection เดียว เรียก SP เดิมทีละเลข (Index Seek ~0.6 ms/ครั้ง)
    public async Task<ParcelSearchResult> SearchAsync(IReadOnlyList<string> trackingNos)
    {
        using var conn = db.Create();
        await conn.OpenAsync();

        var found = new List<ParcelDetail>();
        var notFound = new List<string>();

        foreach (var no in trackingNos)
        {
            var parcel = await conn.QuerySingleOrDefaultAsync<ParcelDetail>(
                "dbo.sp_GetParcelByTrackingNo",
                new { TrackingNo = no },
                commandType: CommandType.StoredProcedure);

            if (parcel is null) notFound.Add(no);
            else found.Add(parcel);
        }

        return new ParcelSearchResult(found, notFound);
    }
}
