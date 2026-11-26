/* =====================================================================
   perf/measure.sql — วัดผลของ Index ต่อ Query หลัก (ก่อน / หลัง)
   ข้อมูลจำลองเพื่อการนำเสนอ (Simulated data)

   รันหลัง 01 → generate_data.py → 02 → 03
   ลบ Index → วัด → สร้าง Index กลับ (ตรงกับ 02_indexes.sql) → วัด → สรุปผล
   ตัวชี้วัดหลักคือ logical reads (คงที่ทุกครั้งที่รัน) ส่วนเวลา (ms) ใช้ประกอบ
   ห้ามรันบน Production: ระหว่างวัดจะไม่มี Index
   ===================================================================== */

USE ParcelHubDemo;
GO
SET NOCOUNT ON;
GO

-- ผลการวัด + ตารางรับผลลัพธ์ของ SP (INSERT ... EXEC) เพื่อไม่ให้แสดงบนจอ
DROP TABLE IF EXISTS #Result;
CREATE TABLE #Result (
    Phase       VARCHAR(10),
    QueryName   SYSNAME,
    AvgReads    BIGINT,
    AvgMs       DECIMAL(10,3)
);

DROP TABLE IF EXISTS #SinkParcel;
CREATE TABLE #SinkParcel (
    TrackingNo CHAR(13), ServiceType VARCHAR(10), CurrentStatus VARCHAR(12), WeightGram INT,
    AcceptedAt DATETIME2(0), ExpectedDeliveryAt DATETIME2(0), DeliveredAt DATETIME2(0), IsDelayed BIT,
    OriginBranch NVARCHAR(100), OriginProvince NVARCHAR(50), DestBranch NVARCHAR(100), DestProvince NVARCHAR(50)
);
DROP TABLE IF EXISTS #SinkEvents;
CREATE TABLE #SinkEvents (
    EventAt DATETIME2(0), Status VARCHAR(12), BranchName NVARCHAR(100), Province NVARCHAR(50), Note NVARCHAR(200)
);
DROP TABLE IF EXISTS #SinkMonthly;
CREATE TABLE #SinkMonthly (
    [Month] NVARCHAR(7), TotalParcels INT, DeliveredParcels INT, DelayedParcels INT,
    OnTimeRate DECIMAL(5,2), AvgDeliveryDays DECIMAL(5,2)
);
DROP TABLE IF EXISTS #SinkBranch;
CREATE TABLE #SinkBranch (
    BranchCode VARCHAR(10), BranchName NVARCHAR(100), Province NVARCHAR(50),
    DeliveredParcels INT, DelayedParcels INT, DelayRate DECIMAL(5,2)
);
GO

-- วัด 1 รอบ: warm-up ให้ข้อมูลอยู่ใน RAM ก่อน แล้วเรียกแต่ละ SP @Runs ครั้ง
-- logical reads = ตัวนับของ Session นี้ (sys.dm_exec_requests) หลังวัด ลบ ก่อนวัด
CREATE OR ALTER PROCEDURE #Measure
    @Phase VARCHAR(10),
    @Runs  INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @No   CHAR(13) = 'EX123456789TH',
            @From DATE     = '2026-10-01',      -- 1 เดือน ตรงกับ /stats/summary?month=2026-10
            @To   DATE     = '2026-10-31',
            @i    INT,
            @t0   DATETIME2(7),
            @r0   BIGINT;

    INSERT #SinkParcel  EXEC dbo.sp_GetParcelByTrackingNo @No;
    INSERT #SinkEvents  EXEC dbo.sp_GetParcelEvents       @No;
    INSERT #SinkMonthly EXEC dbo.sp_GetMonthlySummary     @From, @To;
    INSERT #SinkBranch  EXEC dbo.sp_GetBranchDelays       @From, @To;

    SELECT @i = 0, @t0 = SYSDATETIME(), @r0 = logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID;
    WHILE @i < @Runs BEGIN INSERT #SinkParcel EXEC dbo.sp_GetParcelByTrackingNo @No; SET @i += 1; END;
    INSERT #Result
    SELECT @Phase, 'sp_GetParcelByTrackingNo', (logical_reads - @r0) / @Runs,
           DATEDIFF_BIG(MICROSECOND, @t0, SYSDATETIME()) / 1000.0 / @Runs
    FROM sys.dm_exec_requests WHERE session_id = @@SPID;

    SELECT @i = 0, @t0 = SYSDATETIME(), @r0 = logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID;
    WHILE @i < @Runs BEGIN INSERT #SinkEvents EXEC dbo.sp_GetParcelEvents @No; SET @i += 1; END;
    INSERT #Result
    SELECT @Phase, 'sp_GetParcelEvents', (logical_reads - @r0) / @Runs,
           DATEDIFF_BIG(MICROSECOND, @t0, SYSDATETIME()) / 1000.0 / @Runs
    FROM sys.dm_exec_requests WHERE session_id = @@SPID;

    SELECT @i = 0, @t0 = SYSDATETIME(), @r0 = logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID;
    WHILE @i < @Runs BEGIN INSERT #SinkMonthly EXEC dbo.sp_GetMonthlySummary @From, @To; SET @i += 1; END;
    INSERT #Result
    SELECT @Phase, 'sp_GetMonthlySummary', (logical_reads - @r0) / @Runs,
           DATEDIFF_BIG(MICROSECOND, @t0, SYSDATETIME()) / 1000.0 / @Runs
    FROM sys.dm_exec_requests WHERE session_id = @@SPID;

    SELECT @i = 0, @t0 = SYSDATETIME(), @r0 = logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID;
    WHILE @i < @Runs BEGIN INSERT #SinkBranch EXEC dbo.sp_GetBranchDelays @From, @To; SET @i += 1; END;
    INSERT #Result
    SELECT @Phase, 'sp_GetBranchDelays', (logical_reads - @r0) / @Runs,
           DATEDIFF_BIG(MICROSECOND, @t0, SYSDATETIME()) / 1000.0 / @Runs
    FROM sys.dm_exec_requests WHERE session_id = @@SPID;
END;
GO

-- รอบ "ก่อน": ไม่มี Index
DROP INDEX IF EXISTS UX_Parcel_TrackingNo              ON dbo.Parcel;
DROP INDEX IF EXISTS IX_TrackingEvent_ParcelId_EventAt ON dbo.TrackingEvent;
DROP INDEX IF EXISTS IX_Parcel_AcceptedAt              ON dbo.Parcel;
DROP INDEX IF EXISTS IX_DelayPrediction_ParcelId_RunId ON dbo.DelayPrediction;
GO
EXEC #Measure @Phase = 'Before';
GO

-- รอบ "หลัง": สร้าง Index กลับ (ต้องตรงกับ 02_indexes.sql)
CREATE UNIQUE NONCLUSTERED INDEX UX_Parcel_TrackingNo
    ON dbo.Parcel (TrackingNo);
CREATE NONCLUSTERED INDEX IX_TrackingEvent_ParcelId_EventAt
    ON dbo.TrackingEvent (ParcelId, EventAt)
    INCLUDE (Status, BranchId);
CREATE NONCLUSTERED INDEX IX_Parcel_AcceptedAt
    ON dbo.Parcel (AcceptedAt)
    INCLUDE (OriginBranchId, ExpectedDeliveryAt, DeliveredAt, CurrentStatus, IsDelayed);
CREATE NONCLUSTERED INDEX IX_DelayPrediction_ParcelId_RunId
    ON dbo.DelayPrediction (ParcelId, RunId DESC)
    INCLUDE (Probability, RiskLevel, ModelVersion);
GO
EXEC #Measure @Phase = 'After';
GO

-- สรุปผล (ใช้ในตาราง "ผลการวัด" ของ README)
SELECT  b.QueryName,
        b.AvgReads                                                       AS ReadsBefore,
        a.AvgReads                                                       AS ReadsAfter,
        CAST(1.0 * b.AvgReads / NULLIF(a.AvgReads, 0) AS DECIMAL(10,1)) AS ReadsRatio,
        b.AvgMs                                                          AS MsBefore,
        a.AvgMs                                                          AS MsAfter,
        CAST(b.AvgMs / NULLIF(a.AvgMs, 0) AS DECIMAL(10,1))             AS MsRatio
FROM    #Result b
JOIN    #Result a ON a.QueryName = b.QueryName AND a.Phase = 'After'
WHERE   b.Phase = 'Before'
ORDER BY ReadsRatio DESC;
GO
