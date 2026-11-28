using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using ParcelHub.Api.Auth;
using ParcelHub.Api.Data;
using ParcelHub.Api.Models;

namespace ParcelHub.Api.Controllers;

// ข้อมูลหน้า Dashboard — ผู้ดูแลข้อมูลขึ้นไป (ไม่มี Token → 401, สิทธิ์ไม่พอ → 403)
[ApiController]
[Route("api/v1")]
[Authorize(Policy = Policies.StewardUp)]
[ProducesResponseType(StatusCodes.Status400BadRequest)]
[ProducesResponseType(StatusCodes.Status401Unauthorized)]
[ProducesResponseType(StatusCodes.Status403Forbidden)]
public sealed class StatsController(StatsRepository stats) : ControllerBase
{
    // GET /api/v1/stats/summary?from=2026-01-01&to=2026-11-30
    [HttpGet("stats/summary")]
    [ProducesResponseType<IReadOnlyList<MonthlySummary>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<MonthlySummary>>> GetMonthlySummary(
        [FromQuery, BindRequired] DateOnly from,
        [FromQuery, BindRequired] DateOnly to)
    {
        if (InvalidRange(from, to) is { } problem) return problem;
        return Ok(await stats.GetMonthlySummaryAsync(from, to));
    }

    // GET /api/v1/stats/status?from=2026-11-01&to=2026-11-30
    [HttpGet("stats/status")]
    [ProducesResponseType<IReadOnlyList<StatusCount>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<StatusCount>>> GetStatusSummary(
        [FromQuery, BindRequired] DateOnly from,
        [FromQuery, BindRequired] DateOnly to)
    {
        if (InvalidRange(from, to) is { } problem) return problem;
        return Ok(await stats.GetStatusSummaryAsync(from, to));
    }

    // GET /api/v1/branches/delays?from=2026-01-01&to=2026-11-30&top=5
    [HttpGet("branches/delays")]
    [ProducesResponseType<IReadOnlyList<BranchDelay>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<BranchDelay>>> GetBranchDelays(
        [FromQuery, BindRequired] DateOnly from,
        [FromQuery, BindRequired] DateOnly to,
        [FromQuery] int top = 5)
    {
        if (InvalidRange(from, to) is { } problem) return problem;
        if (top is < 1 or > 20)
            return Problem(statusCode: 400, title: "top ต้องอยู่ระหว่าง 1 ถึง 20");

        return Ok(await stats.GetBranchDelaysAsync(from, to, top));
    }

    // ตรวจก่อนถึง SP เพื่อให้ตอบ 400 แทน 500 จาก THROW
    private ObjectResult? InvalidRange(DateOnly from, DateOnly to) =>
        from > to
            ? Problem(statusCode: 400, title: "from ต้องไม่มากกว่า to")
            : null;
}
