/* =====================================================================
   02_indexes.sql — Parcel Data Service Hub
   ข้อมูลจำลองเพื่อการนำเสนอ (Simulated data)

   สร้าง Index ตาม Query หลักของระบบเท่านั้น (Index เพิ่มความเร็วการอ่าน
   แต่ทำให้ INSERT/UPDATE ช้าลง) · รันหลัง generate_data.py · รันซ้ำได้
   ===================================================================== */

USE ParcelHubDemo;
GO

-- 1) ค้นหาพัสดุจากเลขพัสดุ (sp_GetParcelByTrackingNo) และห้ามเลขพัสดุซ้ำ
DROP INDEX IF EXISTS UX_Parcel_TrackingNo ON dbo.Parcel;
CREATE UNIQUE NONCLUSTERED INDEX UX_Parcel_TrackingNo
    ON dbo.Parcel (TrackingNo);
GO

-- 2) ไทม์ไลน์พัสดุ (sp_GetParcelEvents) — SQL Server ไม่สร้าง Index ให้ Foreign Key อัตโนมัติ
DROP INDEX IF EXISTS IX_TrackingEvent_ParcelId_EventAt ON dbo.TrackingEvent;
CREATE NONCLUSTERED INDEX IX_TrackingEvent_ParcelId_EventAt
    ON dbo.TrackingEvent (ParcelId, EventAt)
    INCLUDE (Status, BranchId);
GO

-- 3) สถิติตามช่วงเวลา (sp_GetMonthlySummary, sp_GetBranchDelays) — Covering Index ใช้ร่วม 2 Query
DROP INDEX IF EXISTS IX_Parcel_AcceptedAt ON dbo.Parcel;
CREATE NONCLUSTERED INDEX IX_Parcel_AcceptedAt
    ON dbo.Parcel (AcceptedAt)
    INCLUDE (OriginBranchId, ExpectedDeliveryAt, DeliveredAt, CurrentStatus, IsDelayed);
GO

-- 4) ผลทำนายล่าสุดของพัสดุ — UQ (RunId, ParcelId) เดิมขึ้นต้นด้วย RunId จึงค้นจาก ParcelId ไม่ได้
DROP INDEX IF EXISTS IX_DelayPrediction_ParcelId_RunId ON dbo.DelayPrediction;
CREATE NONCLUSTERED INDEX IX_DelayPrediction_ParcelId_RunId
    ON dbo.DelayPrediction (ParcelId, RunId DESC)
    INCLUDE (Probability, RiskLevel, ModelVersion);
GO

-- ตรวจผล: ควรเห็น 4 Index
SELECT t.name AS TableName,
       i.name AS IndexName,
       i.type_desc,
       i.is_unique
FROM sys.indexes i
JOIN sys.tables  t ON t.object_id = i.object_id
WHERE t.is_ms_shipped = 0
  AND (i.name LIKE 'IX[_]%' OR i.name LIKE 'UX[_]%')
ORDER BY t.name, i.name;
GO
