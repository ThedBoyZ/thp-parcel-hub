/* =====================================================================
   01_schema.sql — Parcel Data Service Hub
   ข้อมูลจำลองเพื่อการนำเสนอ (Simulated data) — ไม่ใช่ระบบจริงของ บริษัท ไปรษณีย์ไทย จำกัด

   รันซ้ำได้: ลบตารางเดิมทิ้งแล้วสร้างใหม่ (ข้อมูลหายหมด!)
   ต้องการ SQL Server 2016 ขึ้นไป (ใช้ DROP TABLE IF EXISTS)

   หมายเหตุ: ไฟล์นี้ "ยังไม่สร้าง Index เสริม" โดยตั้งใจ
   Index อยู่ใน 02_indexes.sql เพื่อวัดเวลา Query ก่อน/หลังได้
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 0) สร้างฐานข้อมูล (Collation ภาษาไทย ให้เรียงลำดับชื่อไทยถูกต้อง)
-- ---------------------------------------------------------------------
IF DB_ID(N'ParcelHubDemo') IS NULL
    CREATE DATABASE ParcelHubDemo COLLATE Thai_100_CI_AS;
GO

USE ParcelHubDemo;
GO

-- ---------------------------------------------------------------------
-- 1) ลบตารางเดิม — ต้องลบ "ลูก" ก่อน "แม่" เพราะติด Foreign Key
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.DelayPrediction;
DROP TABLE IF EXISTS dbo.TrackingEvent;
DROP TABLE IF EXISTS dbo.Parcel;
DROP TABLE IF EXISTS dbo.Customer;
DROP TABLE IF EXISTS dbo.Branch;
GO

-- ---------------------------------------------------------------------
-- 2) Branch — ที่ทำการไปรษณีย์ และศูนย์คัดแยก (จำลอง)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.Branch (
    BranchId    INT IDENTITY(1,1) NOT NULL,
    BranchCode  VARCHAR(10)   NOT NULL,          -- เช่น 'BR001', 'SC01'
    BranchName  NVARCHAR(100) NOT NULL,          -- ชื่อสมมติ เช่น N'ที่ทำการฯ สาขา A'
    BranchType  VARCHAR(20)   NOT NULL,
    Province    NVARCHAR(50)  NOT NULL,
    Region      NVARCHAR(20)  NOT NULL,          -- ภาคกลาง / ภาคเหนือ / ...
    Latitude    DECIMAL(9,6)  NULL,              -- ใช้คำนวณระยะทาง
    Longitude   DECIMAL(9,6)  NULL,

    CONSTRAINT PK_Branch       PRIMARY KEY (BranchId),
    CONSTRAINT UQ_Branch_Code  UNIQUE (BranchCode),
    CONSTRAINT CK_Branch_Type  CHECK (BranchType IN ('POST_OFFICE', 'SORTING_CENTER'))
);
GO

-- ---------------------------------------------------------------------
-- 3) Customer — ผู้ส่ง/ผู้รับ (ชื่อและเบอร์โทรจาก Faker ทั้งหมด)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.Customer (
    CustomerId    INT IDENTITY(1,1) NOT NULL,
    CustomerCode  VARCHAR(12)   NOT NULL,        -- เช่น 'C000001'
    FullName      NVARCHAR(150) NOT NULL,
    Phone         VARCHAR(20)   NULL,            -- ข้อมูลส่วนบุคคล: API จะส่งแบบปิดบัง (PDPA)
    Province      NVARCHAR(50)  NOT NULL,
    CustomerType  VARCHAR(10)   NOT NULL,
    CreatedAt     DATETIME2(0)  NOT NULL CONSTRAINT DF_Customer_CreatedAt DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Customer       PRIMARY KEY (CustomerId),
    CONSTRAINT UQ_Customer_Code  UNIQUE (CustomerCode),
    CONSTRAINT CK_Customer_Type  CHECK (CustomerType IN ('PERSON', 'BUSINESS'))
);
GO

-- ---------------------------------------------------------------------
-- 4) Parcel — ตารางหลัก 1 แถว = พัสดุ 1 ชิ้น (~100,000 แถว)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.Parcel (
    ParcelId            BIGINT IDENTITY(1,1) NOT NULL,
    TrackingNo          CHAR(13)      NOT NULL,  -- EX123456789TH (ไม่ใส่ UNIQUE ตรงนี้ — ดู 02_indexes.sql)
    ServiceType         VARCHAR(10)   NOT NULL,
    SenderCustomerId    INT           NOT NULL,
    ReceiverCustomerId  INT           NOT NULL,
    OriginBranchId      INT           NOT NULL,
    DestBranchId        INT           NOT NULL,
    WeightGram          INT           NOT NULL,
    DistanceKm          DECIMAL(7,1)  NOT NULL,
    AcceptedAt          DATETIME2(0)  NOT NULL,  -- เวลารับฝาก
    ExpectedDeliveryAt  DATETIME2(0)  NOT NULL,  -- กำหนดถึง (ตาม SLA ของบริการ)
    DeliveredAt         DATETIME2(0)  NULL,      -- NULL = ยังไม่นำจ่าย
    CurrentStatus       VARCHAR(12)   NOT NULL,  -- สถานะล่าสุด (เก็บซ้ำไว้เพื่อให้อ่านเร็ว)

    -- คอลัมน์คำนวณ: ล่าช้าไหม (ใช้เป็น "คำตอบ" ให้โมเดล ML ด้วย)
    -- NULL = ยังไม่นำจ่าย จึงยังตัดสินไม่ได้
    IsDelayed AS CAST(
        CASE
            WHEN DeliveredAt IS NULL               THEN NULL
            WHEN DeliveredAt > ExpectedDeliveryAt  THEN 1
            ELSE 0
        END AS BIT) PERSISTED,

    CONSTRAINT PK_Parcel PRIMARY KEY (ParcelId),

    CONSTRAINT FK_Parcel_Sender   FOREIGN KEY (SenderCustomerId)   REFERENCES dbo.Customer (CustomerId),
    CONSTRAINT FK_Parcel_Receiver FOREIGN KEY (ReceiverCustomerId) REFERENCES dbo.Customer (CustomerId),
    CONSTRAINT FK_Parcel_Origin   FOREIGN KEY (OriginBranchId)     REFERENCES dbo.Branch (BranchId),
    CONSTRAINT FK_Parcel_Dest     FOREIGN KEY (DestBranchId)       REFERENCES dbo.Branch (BranchId),

    -- รูปแบบเลขพัสดุ: ตัวอักษร 2 + ตัวเลข 9 + 'TH' = 13 หลัก
    CONSTRAINT CK_Parcel_TrackingNo CHECK (TrackingNo LIKE
        '[A-Z][A-Z][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]TH'),

    CONSTRAINT CK_Parcel_ServiceType CHECK (ServiceType IN
        ('EMS', 'REG', 'ECO', 'LOGIS', 'EMSW', 'COURIER', 'INTL', 'COD')),

    CONSTRAINT CK_Parcel_Status CHECK (CurrentStatus IN
        ('ACCEPTED', 'SORTING', 'IN_TRANSIT', 'ARRIVED', 'DELIVERED')),

    CONSTRAINT CK_Parcel_Weight   CHECK (WeightGram > 0),
    CONSTRAINT CK_Parcel_Distance CHECK (DistanceKm >= 0),
    CONSTRAINT CK_Parcel_Due      CHECK (ExpectedDeliveryAt >= AcceptedAt),

    -- กติกาความสอดคล้อง: นำจ่ายแล้ว <=> ต้องมีเวลานำจ่าย
    CONSTRAINT CK_Parcel_Delivered CHECK (
        (CurrentStatus = 'DELIVERED'  AND DeliveredAt IS NOT NULL AND DeliveredAt >= AcceptedAt)
     OR (CurrentStatus <> 'DELIVERED' AND DeliveredAt IS NULL)
    )
);
GO

-- ---------------------------------------------------------------------
-- 5) TrackingEvent — ประวัติการเคลื่อนไหว 1 พัสดุ มีหลายเหตุการณ์ (~3-5 แถว/ชิ้น)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.TrackingEvent (
    EventId   BIGINT IDENTITY(1,1) NOT NULL,
    ParcelId  BIGINT        NOT NULL,
    Status    VARCHAR(12)   NOT NULL,
    BranchId  INT           NOT NULL,            -- เกิดที่ที่ทำการ/ศูนย์คัดแยกไหน
    EventAt   DATETIME2(0)  NOT NULL,
    Note      NVARCHAR(200) NULL,

    CONSTRAINT PK_TrackingEvent        PRIMARY KEY (EventId),
    CONSTRAINT FK_TrackingEvent_Parcel FOREIGN KEY (ParcelId) REFERENCES dbo.Parcel (ParcelId),
    CONSTRAINT FK_TrackingEvent_Branch FOREIGN KEY (BranchId) REFERENCES dbo.Branch (BranchId),
    CONSTRAINT CK_TrackingEvent_Status CHECK (Status IN
        ('ACCEPTED', 'SORTING', 'IN_TRANSIT', 'ARRIVED', 'DELIVERED'))
);
GO

-- ---------------------------------------------------------------------
-- 6) DelayPrediction — ผลจาก predict.py (เว็บอ่านจากตารางนี้ ไม่คำนวณสด)
--    เก็บประวัติทุกรอบ: 1 รอบ (RunId) = 1 ครั้งที่กดปุ่ม "คำนวณความเสี่ยงใหม่"
-- ---------------------------------------------------------------------
CREATE TABLE dbo.DelayPrediction (
    PredictionId  BIGINT IDENTITY(1,1) NOT NULL,
    RunId         INT           NOT NULL,
    ParcelId      BIGINT        NOT NULL,
    Probability   DECIMAL(5,4)  NOT NULL,        -- 0.0000 - 1.0000
    RiskLevel     VARCHAR(6)    NOT NULL,
    TopFactors    NVARCHAR(400) NULL,            -- JSON เช่น [{"factor":"DistanceKm","weight":0.41}]
    ModelVersion  VARCHAR(30)   NOT NULL,        -- เช่น 'rf-2026-11-27'
    PredictedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_DelayPrediction_PredictedAt DEFAULT SYSDATETIME(),

    CONSTRAINT PK_DelayPrediction            PRIMARY KEY (PredictionId),
    CONSTRAINT FK_DelayPrediction_Parcel     FOREIGN KEY (ParcelId) REFERENCES dbo.Parcel (ParcelId),
    CONSTRAINT UQ_DelayPrediction_RunParcel  UNIQUE (RunId, ParcelId),   -- 1 รอบ ประเมินพัสดุชิ้นละครั้ง
    CONSTRAINT CK_DelayPrediction_Prob       CHECK (Probability BETWEEN 0 AND 1),
    CONSTRAINT CK_DelayPrediction_Risk       CHECK (RiskLevel IN ('Low', 'Medium', 'High'))
);
GO

-- ---------------------------------------------------------------------
-- 7) ตรวจผล: ควรเห็น 5 ตาราง
-- ---------------------------------------------------------------------
SELECT t.name AS TableName,
       SUM(p.rows) AS [Rows]
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY t.name
ORDER BY t.name;
GO
