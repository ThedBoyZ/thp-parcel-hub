using System.Text.RegularExpressions;

namespace ParcelHub.Api.Models;

// แถวจาก sp_GetParcelByTrackingNo — ไม่มีข้อมูลส่วนบุคคล (endpoint สาธารณะ, PDPA)
public sealed class ParcelDetail
{
    public string TrackingNo { get; init; } = "";
    public string ServiceType { get; init; } = "";
    public string CurrentStatus { get; init; } = "";
    public int WeightGram { get; init; }
    public DateTime AcceptedAt { get; init; }
    public DateTime ExpectedDeliveryAt { get; init; }
    public DateTime? DeliveredAt { get; init; }         // NULL = ยังไม่นำจ่าย
    public bool? IsDelayed { get; init; }               // NULL = ยังตัดสินไม่ได้
    public string OriginBranch { get; init; } = "";
    public string OriginProvince { get; init; } = "";
    public string DestBranch { get; init; } = "";
    public string DestProvince { get; init; } = "";
}

// แถวจาก sp_GetParcelEvents (1 แถว = 1 จุดบนไทม์ไลน์)
public sealed class ParcelEvent
{
    public DateTime EventAt { get; init; }
    public string Status { get; init; } = "";
    public string BranchName { get; init; } = "";
    public string Province { get; init; } = "";
    public string? Note { get; init; }
}

// ผลค้นหาหลายหมายเลข — แยกเลขที่พบและไม่พบ
public sealed record ParcelSearchResult(
    IReadOnlyList<ParcelDetail> Found,
    IReadOnlyList<string> NotFound);

// รูปแบบเลขพัสดุเดียวกับ CHECK ใน 01_schema.sql: ตัวอักษร 2 + ตัวเลข 9 + TH
public static class TrackingNumber
{
    public const int MaxPerSearch = 10;

    private static readonly Regex Pattern = new("^[A-Z]{2}[0-9]{9}TH$", RegexOptions.Compiled);

    public static string Normalize(string input) => input.Trim().ToUpperInvariant();

    public static bool IsValid(string normalized) => Pattern.IsMatch(normalized);
}
