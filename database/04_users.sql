/* =====================================================================
   04_users.sql — ผู้ใช้งานระบบ + SP สำหรับเข้าสู่ระบบ
   ข้อมูลจำลองเพื่อการนำเสนอ (Simulated data)

   รันซ้ำได้ (สร้างตาราง AppUser ใหม่) · ไม่กระทบข้อมูลพัสดุ
   เก็บเฉพาะ Password Hash จาก ASP.NET Core PasswordHasher
   (PBKDF2-HMAC-SHA512, 100,000 รอบ, Salt สุ่มต่อบัญชี)
   บัญชีทดลอง: staff01 / steward01 / admin01 · รหัสผ่าน Demo@2026
   ===================================================================== */

USE ParcelHubDemo;
GO

DROP TABLE IF EXISTS dbo.AppUser;
GO

CREATE TABLE dbo.AppUser (
    UserId        INT IDENTITY(1,1) NOT NULL,
    Username      VARCHAR(50)    NOT NULL,
    PasswordHash  VARCHAR(200)   NOT NULL,
    Role          VARCHAR(20)    NOT NULL,          -- ตรงกับ Auth/Roles.cs ในฝั่ง API
    DisplayName   NVARCHAR(100)  NOT NULL,
    IsActive      BIT            NOT NULL CONSTRAINT DF_AppUser_IsActive  DEFAULT 1,
    CreatedAt     DATETIME2(0)   NOT NULL CONSTRAINT DF_AppUser_CreatedAt DEFAULT SYSDATETIME(),

    CONSTRAINT PK_AppUser          PRIMARY KEY (UserId),
    CONSTRAINT UQ_AppUser_Username UNIQUE (Username),
    CONSTRAINT CK_AppUser_Role     CHECK (Role IN ('Staff', 'DataSteward', 'Admin'))
);
GO

-- บัญชีทดลอง: Hash ของ 'Demo@2026' (Salt ต่างกันทุกบัญชี)
INSERT INTO dbo.AppUser (Username, PasswordHash, Role, DisplayName) VALUES
('staff01',   'AQAAAAIAAYagAAAAELDuGzLorScC9J9XhA2LmxXf5eQKNri9RsvdR0UJPmbEVEZHZnp+aft4huPDfUfrWg==', 'Staff',       N'เจ้าหน้าที่ (ทดลอง)'),
('steward01', 'AQAAAAIAAYagAAAAEJOyLEjQpMcdr4A7/oUulM22roK4yBIik22OXu1+TdrFaR8ovTmrdDE+jPL/O/Stqw==', 'DataSteward', N'ผู้ดูแลข้อมูล (ทดลอง)'),
('admin01',   'AQAAAAIAAYagAAAAEItgMGHfDrTWcOpqbqmVLxr4cpzXWRkTC6D1dmsbjEOaBW+TvjpKWx0+IS+oqPSyiQ==', 'Admin',       N'ผู้ดูแลระบบ (ทดลอง)');
GO

-- ผู้ใช้สำหรับ Login — POST /api/v1/auth/login
-- คืน Hash ให้ API ตรวจรหัสผ่าน · เฉพาะบัญชีที่ยังใช้งานอยู่
CREATE OR ALTER PROCEDURE dbo.sp_GetUserForLogin
    @Username VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  UserId,
            Username,
            PasswordHash,
            Role,
            DisplayName
    FROM    dbo.AppUser
    WHERE   Username = @Username
      AND   IsActive = 1;
END;
GO

-- ตรวจผล: ควรเห็น 3 บัญชี
SELECT UserId, Username, Role, DisplayName, IsActive FROM dbo.AppUser;
GO
