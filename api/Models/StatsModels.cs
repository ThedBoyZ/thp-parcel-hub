namespace ParcelHub.Api.Models;

// แถวจาก sp_GetMonthlySummary — กราฟรายเดือนในหน้า Dashboard
public sealed class MonthlySummary
{
    public string Month { get; init; } = "";        // yyyy-MM
    public int TotalParcels { get; init; }
    public int DeliveredParcels { get; init; }
    public int DelayedParcels { get; init; }
    public decimal? OnTimeRate { get; init; }       // NULL เมื่อเดือนนั้นยังไม่มีพัสดุนำจ่าย
    public decimal? AvgDeliveryDays { get; init; }
}

// แถวจาก sp_GetStatusSummary — จำนวนพัสดุตามสถานะ
public sealed class StatusCount
{
    public string Status { get; init; } = "";
    public int Parcels { get; init; }
    public int DelayedParcels { get; init; }
}

// แถวจาก sp_GetBranchDelays — อันดับสาขาที่ส่งล่าช้า
public sealed class BranchDelay
{
    public string BranchCode { get; init; } = "";
    public string BranchName { get; init; } = "";
    public string Province { get; init; } = "";
    public int DeliveredParcels { get; init; }
    public int DelayedParcels { get; init; }
    public decimal DelayRate { get; init; }         // %
}
