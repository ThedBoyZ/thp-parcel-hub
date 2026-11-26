/* =====================================================================
   03_stored_procedures.sql — Parcel Data Service Hub
   ข้อมูลจำลองเพื่อการนำเสนอ (Simulated data)

   API เรียกข้อมูลผ่าน Stored Procedure เท่านั้น (ไม่มี SQL ในโค้ด C#)
   · รันซ้ำได้ (CREATE OR ALTER)
   · SP ผลทำนายความเสี่ยง (DelayPrediction) เพิ่มในขั้น ML
   ===================================================================== */

USE ParcelHubDemo;
GO

-- 1) ข้อมูลพัสดุ 1 ชิ้น — GET /api/v1/parcels/{no} (ทุกคน)
--    ไม่ JOIN Customer: endpoint สาธารณะจึงไม่ส่งข้อมูลส่วนบุคคล (PDPA)
CREATE OR ALTER PROCEDURE dbo.sp_GetParcelByTrackingNo
    @TrackingNo CHAR(13)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  p.TrackingNo,
            p.ServiceType,
            p.CurrentStatus,
            p.WeightGram,
            p.AcceptedAt,
            p.ExpectedDeliveryAt,
            p.DeliveredAt,
            p.IsDelayed,
            o.BranchName  AS OriginBranch,
            o.Province    AS OriginProvince,
            d.BranchName  AS DestBranch,
            d.Province    AS DestProvince
    FROM    dbo.Parcel p
    JOIN    dbo.Branch o ON o.BranchId = p.OriginBranchId
    JOIN    dbo.Branch d ON d.BranchId = p.DestBranchId
    WHERE   p.TrackingNo = @TrackingNo;
END;
GO

-- 2) ไทม์ไลน์พัสดุ — GET /api/v1/parcels/{no}/events (ทุกคน)
--    รับเลขพัสดุแทน ParcelId เพื่อไม่เปิดเผย Id ภายในระบบ
CREATE OR ALTER PROCEDURE dbo.sp_GetParcelEvents
    @TrackingNo CHAR(13)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  e.EventAt,
            e.Status,
            b.BranchName,
            b.Province,
            e.Note
    FROM    dbo.Parcel p
    JOIN    dbo.TrackingEvent e ON e.ParcelId = p.ParcelId
    JOIN    dbo.Branch b        ON b.BranchId = e.BranchId
    WHERE   p.TrackingNo = @TrackingNo
    ORDER BY e.EventAt;
END;
GO

-- 3) สรุปรายเดือน — GET /api/v1/stats/summary (ผู้ดูแลข้อมูล)
--    กรองช่วงวันที่แบบ SARGable เพื่อใช้ IX_Parcel_AcceptedAt
--    อัตราตรงเวลาและเวลานำส่งเฉลี่ย คิดจากพัสดุที่นำจ่ายแล้วเท่านั้น
CREATE OR ALTER PROCEDURE dbo.sp_GetMonthlySummary
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @FromDate > @ToDate
        THROW 50001, N'@FromDate ต้องไม่มากกว่า @ToDate', 1;

    SELECT  FORMAT(DATEFROMPARTS(YEAR(AcceptedAt), MONTH(AcceptedAt), 1), 'yyyy-MM') AS [Month],
            COUNT(*)                                          AS TotalParcels,
            COUNT(DeliveredAt)                                AS DeliveredParcels,
            SUM(CASE WHEN IsDelayed = 1 THEN 1 ELSE 0 END)    AS DelayedParcels,
            CAST(100.0 * SUM(CASE WHEN IsDelayed = 0 THEN 1 ELSE 0 END)
                 / NULLIF(COUNT(DeliveredAt), 0) AS DECIMAL(5,2))            AS OnTimeRate,
            CAST(AVG(DATEDIFF(MINUTE, AcceptedAt, DeliveredAt) / 1440.0)
                 AS DECIMAL(5,2))                                            AS AvgDeliveryDays
    FROM    dbo.Parcel
    WHERE   AcceptedAt >= @FromDate
      AND   AcceptedAt <  DATEADD(DAY, 1, @ToDate)
    GROUP BY YEAR(AcceptedAt), MONTH(AcceptedAt)
    ORDER BY YEAR(AcceptedAt), MONTH(AcceptedAt);
END;
GO

-- 4) อันดับสาขาต้นทางที่ส่งล่าช้า — GET /api/v1/branches/delays (ผู้ดูแลข้อมูล)
--    @MinParcels ตัดสาขาที่พัสดุน้อยเกินไปจนอัตราล่าช้าไม่น่าเชื่อถือ
CREATE OR ALTER PROCEDURE dbo.sp_GetBranchDelays
    @FromDate   DATE,
    @ToDate     DATE,
    @Top        INT = 5,
    @MinParcels INT = 100
AS
BEGIN
    SET NOCOUNT ON;

    IF @FromDate > @ToDate
        THROW 50001, N'@FromDate ต้องไม่มากกว่า @ToDate', 1;

    WITH BranchStats AS (
        SELECT  OriginBranchId,
                COUNT(DeliveredAt)                              AS DeliveredParcels,
                SUM(CASE WHEN IsDelayed = 1 THEN 1 ELSE 0 END)  AS DelayedParcels
        FROM    dbo.Parcel
        WHERE   AcceptedAt >= @FromDate
          AND   AcceptedAt <  DATEADD(DAY, 1, @ToDate)
        GROUP BY OriginBranchId
    )
    SELECT TOP (@Top)
            b.BranchCode,
            b.BranchName,
            b.Province,
            s.DeliveredParcels,
            s.DelayedParcels,
            CAST(100.0 * s.DelayedParcels / s.DeliveredParcels AS DECIMAL(5,2)) AS DelayRate
    FROM    BranchStats s
    JOIN    dbo.Branch b ON b.BranchId = s.OriginBranchId
    WHERE   s.DeliveredParcels >= @MinParcels
    ORDER BY DelayRate DESC;
END;
GO

-- 5) จำนวนพัสดุตามสถานะปัจจุบัน — หน้า Dashboard
--    อ่านจาก Parcel.CurrentStatus (Denormalize) ไม่ต้องค้น TrackingEvent
CREATE OR ALTER PROCEDURE dbo.sp_GetStatusSummary
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @FromDate > @ToDate
        THROW 50001, N'@FromDate ต้องไม่มากกว่า @ToDate', 1;

    SELECT  CurrentStatus                                   AS [Status],
            COUNT(*)                                        AS Parcels,
            SUM(CASE WHEN IsDelayed = 1 THEN 1 ELSE 0 END)  AS DelayedParcels
    FROM    dbo.Parcel
    WHERE   AcceptedAt >= @FromDate
      AND   AcceptedAt <  DATEADD(DAY, 1, @ToDate)
    GROUP BY CurrentStatus
    ORDER BY CASE CurrentStatus
                WHEN 'ACCEPTED'   THEN 1
                WHEN 'SORTING'    THEN 2
                WHEN 'IN_TRANSIT' THEN 3
                WHEN 'ARRIVED'    THEN 4
                WHEN 'DELIVERED'  THEN 5
             END;
END;
GO

-- ตัวอย่างการเรียกใช้
EXEC dbo.sp_GetParcelByTrackingNo @TrackingNo = 'EX123456789TH';
EXEC dbo.sp_GetParcelEvents       @TrackingNo = 'EX123456789TH';
EXEC dbo.sp_GetMonthlySummary     @FromDate = '2026-01-01', @ToDate = '2026-11-30';
EXEC dbo.sp_GetBranchDelays       @FromDate = '2026-01-01', @ToDate = '2026-11-30';
EXEC dbo.sp_GetStatusSummary      @FromDate = '2026-11-01', @ToDate = '2026-11-30';
GO
