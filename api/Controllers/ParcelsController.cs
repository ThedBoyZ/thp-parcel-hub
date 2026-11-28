using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using ParcelHub.Api.Data;
using ParcelHub.Api.Infrastructure;
using ParcelHub.Api.Models;

namespace ParcelHub.Api.Controllers;

// ติดตามพัสดุ — ไม่ต้องเข้าสู่ระบบ จึงจำกัดความถี่ต่อ IP และไม่ส่งข้อมูลส่วนบุคคล
[ApiController]
[Route("api/v1/parcels")]
[EnableRateLimiting(RateLimits.Public)]
[ProducesResponseType(StatusCodes.Status400BadRequest)]
[ProducesResponseType(StatusCodes.Status429TooManyRequests)]
public sealed class ParcelsController(ParcelRepository parcels) : ControllerBase
{
    // GET /api/v1/parcels?numbers=EX123456789TH,EX555000111TH
    [HttpGet]
    [ProducesResponseType<ParcelSearchResult>(StatusCodes.Status200OK)]
    public async Task<ActionResult<ParcelSearchResult>> Search([FromQuery] string? numbers)
    {
        var list = (numbers ?? "")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(TrackingNumber.Normalize)
            .Distinct()
            .ToList();

        if (list.Count == 0)
            return Problem(statusCode: 400, title: "กรุณาระบุหมายเลขพัสดุอย่างน้อย 1 หมายเลข");

        if (list.Count > TrackingNumber.MaxPerSearch)
            return Problem(statusCode: 400,
                title: $"ค้นหาได้ครั้งละไม่เกิน {TrackingNumber.MaxPerSearch} หมายเลข");

        var invalid = list.Where(n => !TrackingNumber.IsValid(n)).ToList();
        if (invalid.Count > 0)
            return Problem(statusCode: 400,
                title: "รูปแบบหมายเลขพัสดุไม่ถูกต้อง (ตัวอักษร 2 ตัว + ตัวเลข 9 หลัก + TH)",
                detail: string.Join(", ", invalid));

        return Ok(await parcels.SearchAsync(list));
    }

    // GET /api/v1/parcels/EX123456789TH
    [HttpGet("{no}")]
    [ProducesResponseType<ParcelDetail>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ParcelDetail>> GetByTrackingNo(string no)
    {
        no = TrackingNumber.Normalize(no);
        if (!TrackingNumber.IsValid(no))
            return Problem(statusCode: 400, title: "รูปแบบหมายเลขพัสดุไม่ถูกต้อง", detail: no);

        var parcel = await parcels.GetByTrackingNoAsync(no);
        return parcel is null
            ? Problem(statusCode: 404, title: "ไม่พบหมายเลขพัสดุ", detail: no)
            : Ok(parcel);
    }

    // GET /api/v1/parcels/EX123456789TH/events
    [HttpGet("{no}/events")]
    [ProducesResponseType<IReadOnlyList<ParcelEvent>>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IReadOnlyList<ParcelEvent>>> GetEvents(string no)
    {
        no = TrackingNumber.Normalize(no);
        if (!TrackingNumber.IsValid(no))
            return Problem(statusCode: 400, title: "รูปแบบหมายเลขพัสดุไม่ถูกต้อง", detail: no);

        // พัสดุทุกชิ้นมีเหตุการณ์รับฝากอย่างน้อย 1 รายการ — 0 แถว = ไม่พบพัสดุ
        var events = await parcels.GetEventsAsync(no);
        return events.Count == 0
            ? Problem(statusCode: 404, title: "ไม่พบหมายเลขพัสดุ", detail: no)
            : Ok(events);
    }
}
