# THP Parcel Data Service Hub — ระบบบริการข้อมูลพัสดุ `DEMO`

> **ข้อมูลจำลองเพื่อการนำเสนอ (Simulated data)**
> โปรเจกต์ส่วนตัวเพื่อประกอบการสัมภาษณ์งาน **ไม่ใช่ระบบทางการของ บริษัท ไปรษณีย์ไทย จำกัด**
> ไม่ใช้ข้อมูลจริง โลโก้ ภาพ หรือเนื้อหาของไปรษณีย์ไทย

ระบบตัวอย่างสำหรับเจ้าหน้าที่ ใช้ **ติดตามพัสดุ ดูสถิติการให้บริการ และดูพัสดุที่มีความเสี่ยงล่าช้า**
พัฒนาครบทุกชั้น: **SQL Server → ASP.NET Core REST API → Angular**
และใช้ **Python** ทำนายความเสี่ยงพัสดุล่าช้า

<!-- TODO: รอจนกว่าจะมีภาพ demo image -->
![หน้าติดตามพัสดุ](docs/images/tracking.png)

---

## สารบัญ

- [สถาปัตยกรรมระบบ](#สถาปัตยกรรมระบบ)
- [ความสามารถของระบบ](#ความสามารถของระบบ)
- [เทคโนโลยีที่ใช้](#เทคโนโลยีที่ใช้)
- [ผลการวัด](#ผลการวัด)
- [วิธีติดตั้งและรัน](#วิธีติดตั้งและรัน)
- [API](#api)
- [โครงสร้างโปรเจกต์](#โครงสร้างโปรเจกต์)
- [เหตุผลการออกแบบ](#เหตุผลการออกแบบ)
- [ข้อจำกัดและแผนต่อยอด](#ข้อจำกัดและแผนต่อยอด)
- [English summary](#english-summary)

---

## สถาปัตยกรรมระบบ

```mermaid
flowchart LR
    U[ผู้ใช้ / Browser] --> W[Angular Web]
    W -->|REST + JWT| A[ASP.NET Core API บน IIS]
    A -->|Dapper / Stored Procedure| D[(SQL Server)]
    A -.->|API log, เสริม| M[(MongoDB)]
    P[Python predict.py] -->|อ่านพัสดุ / เขียนผลทำนาย| D
    A -->|POST /predictions/run| P
```

- หน้าเว็บ **ไม่ต่อฐานข้อมูลตรง** ทุกข้อมูลผ่าน API
- API เรียก **Stored Procedure** ผ่าน **Dapper** ไม่มี SQL ปนในโค้ด C#
- ความเสี่ยงล่าช้า **คำนวณล่วงหน้า** ด้วย `predict.py` แล้วเก็บในตาราง `DelayPrediction`
  หน้าเว็บอ่านผลจากตาราง ไม่รันโมเดลทุกครั้งที่เปิดหน้า

ER Diagram: [docs/er-diagram.md](docs/er-diagram.md)

---

## ความสามารถของระบบ

<!-- เฉพาะสิ่งที่ทำงานได้จริงใน Demo เท่านั้น -->

| ความสามารถ | สถานะ |
|---|---|
| เข้าสู่ระบบด้วย JWT (บทบาท: เจ้าหน้าที่ / ผู้ดูแลข้อมูล / ผู้ดูแลระบบ) | ✅ |
| ค้นหาพัสดุได้ครั้งละสูงสุด 10 หมายเลข (คั่นด้วย Comma) โดยไม่ต้องเข้าสู่ระบบ | ⬜ |
| ไทม์ไลน์สถานะพัสดุ (รับฝาก → คัดแยก → ขนส่ง → ถึงที่ทำการ → นำจ่าย) | ⬜ |
| Dashboard จำนวนพัสดุรายเดือนและอัตราส่งตรงเวลา | ⬜ |
| อันดับสาขาที่ส่งล่าช้า | ⬜ |
| คาดการณ์ความเสี่ยงล่าช้า (Low / Medium / High) | ⬜ |
| ปุ่ม "คำนวณความเสี่ยงใหม่" (สั่งรัน `predict.py`) | ⬜ |
| เอกสาร API ด้วย Swagger | ✅ |
| บันทึก API log ลง MongoDB | ⬜ เสริม |
| Deploy บน IIS | ✅ |

---

## เทคโนโลยีที่ใช้

| ส่วน | เทคโนโลยี |
|---|---|
| ฐานข้อมูล | SQL Server 2025, Stored Procedure, Index |
| Back End | ASP.NET Core (.NET 10) Web API, Dapper, JWT, Swagger |
| Front End | Angular 21 |
| Data Science | Python 3.12, pandas, scikit-learn, Faker |
| Web Server | IIS |
| เครื่องมือ | Visual Studio 2026 (API), VS Code (Angular, Python), SSMS |

---

## ผลการวัด

วัดบนข้อมูลจำลอง **พัสดุ 100,000 รายการ / เหตุการณ์ ~500,000 รายการ** ในเครื่องของผู้พัฒนา

### ผลของ Index ต่อความเร็ว Query

| Query | ก่อนทำ Index (logical reads / ms) | หลังทำ Index (logical reads / ms) | อ่านข้อมูลน้อยลง | เร็วขึ้น |
|---|---|---|---|---|
| `sp_GetParcelEvents` | 4,117 / 242 ms | 36 / 0.4 ms | 114 เท่า | 601 เท่า |
| `sp_GetParcelByTrackingNo` | 1,183 / 38 ms | 18 / 0.6 ms | 66 เท่า | 59 เท่า |
| `sp_GetMonthlySummary` (1 เดือน) | 1,210 / 66 ms | 87 / 29 ms | 14 เท่า | 2.3 เท่า |
| `sp_GetBranchDelays` (1 เดือน) | 1,291 / 31 ms | 159 / 8.8 ms | 8 เท่า | 3.5 เท่า |

วิธีวัด: เรียกแต่ละ SP 20 ครั้งหลัง warm-up แล้วหาค่าเฉลี่ยต่อครั้ง · logical reads คงที่ทุกครั้งที่รัน ส่วนเวลาแกว่งตามเครื่อง
สคริปต์: [database/perf/measure.sql](database/perf/measure.sql)
สรุปรายเดือนเร็วขึ้นน้อยกว่า เพราะยังต้องนับพัสดุทั้งเดือน (~12,000 ชิ้น) Index ช่วยให้อ่านเฉพาะเดือนนั้นแทนการอ่านทั้งปี

### โมเดลทำนายความเสี่ยงล่าช้า

| โมเดล | Accuracy | Precision | Recall |
|---|---|---|---|
| Logistic Regression | [XX] | [XX] | [XX] |
| Random Forest | [XX] | [XX] | [XX] |

ปัจจัยที่ใช้: ระยะทาง, น้ำหนัก, ช่วงเวลารับฝาก, สาขาต้นทาง · `random_state = [XX]` (รันซ้ำได้ผลเดิม)
รายละเอียด: [ml/train_model.ipynb](ml/train_model.ipynb)

---

## วิธีติดตั้งและรัน

### สิ่งที่ต้องมี

| เครื่องมือ | เวอร์ชันที่ใช้พัฒนา | ตรวจสอบด้วย |
|---|---|---|
| SQL Server (Express) | 2025 (17.0) | `SELECT @@VERSION` |
| SSMS | 22 | Help → About |
| ODBC Driver for SQL Server | 18 | ใช้โดย Python (pyodbc) · ปกติติดมากับ SQL Server/SSMS |
| .NET SDK | 10.0 | `dotnet --version` |
| Node.js | 22 LTS | `node --version` |
| Angular CLI | 21 | `ng version` |
| Python | 3.12 | `python --version` |

### 1. ฐานข้อมูล

รันใน SSMS ตามลำดับ:

```text
database/01_schema.sql
database/03_stored_procedures.sql
database/04_users.sql
```

### 2. สร้างข้อมูลจำลอง

สร้าง virtual environment ด้วย Python 3.12 ที่โฟลเดอร์หลักของโปรเจกต์ (ทำครั้งแรกครั้งเดียว)

```bash
py -3.12 -m venv thp-parcel-hub
thp-parcel-hub\Scripts\activate
```

```bash
cd data-generator
pip install -r requirements.txt
python generate_data.py
```

จากนั้นรัน `database/02_indexes.sql`

### 3. API

```bash
cd api
# คัดลอกไฟล์ตั้งค่าตัวอย่าง แล้วใส่ Connection String และ JWT Key (ข้อความสุ่มยาว 32 ตัวอักษรขึ้นไป)
copy appsettings.Example.json appsettings.Development.json
dotnet run --launch-profile http
```

Swagger: `http://localhost:5209/swagger` · ทดสอบเร็ว ๆ ได้จาก `api/ParcelHub.Api.http`
หรือเปิด `api/ParcelHub.slnx` ใน Visual Studio แล้วกด F5

### 4. หน้าเว็บ

```bash
cd web
npm install
ng serve
```

เปิด `http://localhost:4200`

### 5. Deploy (Demo บน IIS)

Demo: **https://thp-parcelhub-demo.duckdns.org/swagger** (เปิดเฉพาะช่วงนำเสนอ)

| ส่วน | ที่ใช้ |
|---|---|
| Server | AWS EC2 · Windows Server 2025 |
| Web server | IIS + ASP.NET Core Hosting Bundle (.NET 10) |
| Database | SQL Server 2025 Express (restore จากไฟล์ `.bak`) |
| Domain / HTTPS | DuckDNS + Let's Encrypt (win-acme ต่ออายุอัตโนมัติ) |

```bash
dotnet publish api/ParcelHub.Api.csproj -c Release -o publish/api
```

1. Copy `publish/api` ไปไว้ที่ `C:\inetpub\parcelhub` บนเซิร์ฟเวอร์
2. สร้าง `appsettings.Production.json` บนเซิร์ฟเวอร์จาก `appsettings.Production.Example.json` ด้วย JWT Key ชุดใหม่ (ไม่ขึ้น Git)
3. IIS App Pool ตั้งเป็น **No Managed Code**
4. สิทธิ์ฐานข้อมูลของ App Pool: `GRANT EXECUTE` อย่างเดียว เรียกได้แค่ Stored Procedure ไม่มีสิทธิ์อ่าน/เขียนตารางตรง

### บัญชีทดลอง (จำลอง)

| บทบาท | Username | Password |
|---|---|---|
| เจ้าหน้าที่ | `staff01` | `Demo@2026` |
| ผู้ดูแลข้อมูล | `steward01` | `Demo@2026` |
| ผู้ดูแลระบบ | `admin01` | `Demo@2026` |

---

## API

Base URL: `/api/v1`

| Method | Path | คำอธิบาย | สิทธิ์ |
|---|---|---|---|
| POST | `/auth/login` | รับ JWT | ทุกคน |
| GET | `/auth/me` | ข้อมูลผู้ใช้จาก Token | ผู้ที่เข้าสู่ระบบ |
| GET | `/parcels/{no}` | ข้อมูลและสถานะพัสดุ (ไม่มีชื่อ/เบอร์โทร) | ทุกคน |
| GET | `/parcels/{no}/events` | ไทม์ไลน์เหตุการณ์ | ทุกคน |
| GET | `/stats/summary?month=` | สถิติสรุปรายเดือน | ผู้ดูแลข้อมูล |
| GET | `/branches/delays` | อัตราล่าช้ารายสาขา | ผู้ดูแลข้อมูล |
| GET | `/predictions/{no}` | ความเสี่ยงล่าช้าของพัสดุ | เจ้าหน้าที่ |
| POST | `/predictions/run` | คำนวณความเสี่ยงใหม่ | ผู้ดูแลข้อมูล |
| GET | `/logs` | บันทึกการเรียก API | ผู้ดูแลระบบ |

สิทธิ์เป็นลำดับขั้น: ผู้ดูแลระบบ ทำได้ทุกอย่างที่ผู้ดูแลข้อมูลทำได้ และผู้ดูแลข้อมูล ทำได้ทุกอย่างที่เจ้าหน้าที่ทำได้

รหัสตอบกลับ: `200` สำเร็จ · `401` ยังไม่เข้าสู่ระบบ · `403` สิทธิ์ไม่พอ · `404` ไม่พบพัสดุ · `429` เรียกถี่เกินกำหนด

---

## โครงสร้างโปรเจกต์

```text
parcel-data-service-hub/
├─ database/        Schema, Index, Stored Procedure, สคริปต์วัดเวลา
├─ data-generator/  สคริปต์ Faker สร้างข้อมูลจำลอง
├─ api/             ASP.NET Core Web API (Visual Studio Solution)
├─ web/             Angular Front End
├─ ml/              Notebook ฝึกโมเดล และ predict.py
└─ docs/            ER Diagram, รูปภาพ
```

---

## เหตุผลการออกแบบ

- **ใช้ Dapper + Stored Procedure แทน EF Core:** เห็น SQL ชัดเจน ปรับจูนประสิทธิภาพได้ตรงจุด
  และเหมาะกับการทำงานร่วมกับทีมฐานข้อมูล
- **เก็บ `CurrentStatus` ไว้ในตาราง `Parcel` (Denormalize โดยตั้งใจ):** หน้าติดตามพัสดุอ่านสถานะล่าสุดได้ทันที
  ไม่ต้องค้นประวัติเหตุการณ์ทุกครั้ง ข้อแลกเปลี่ยนคือต้องอัปเดตพร้อมกับการเพิ่มเหตุการณ์ใหม่
- **เก็บผลทำนายไว้ในตาราง ไม่คำนวณสด:** หน้าเว็บโหลดเร็ว และผลคงที่ตรวจสอบย้อนหลังได้
  ในระบบจริงจะตั้งเวลาฝึกโมเดลใหม่เป็นรอบ ผ่านผู้ดูแลที่มีสิทธิ์
- **รองรับการย้ายไป Oracle:** ใช้รหัสสถานะแบบข้อความธรรมดา และหลีกเลี่ยงชนิดข้อมูลเฉพาะของ SQL Server
  ส่วน Stored Procedure ต้องเขียนใหม่เป็น PL/SQL
- **ข้อมูลส่วนบุคคล (PDPA):** ชื่อและเบอร์โทรเป็นข้อมูลจำลองทั้งหมด และ API ค้นหาพัสดุที่เปิดให้ทุกคนใช้ ไม่ส่งชื่อหรือเบอร์โทรออกไปเลย (Stored Procedure ไม่ JOIN ตาราง Customer)
- **Deploy บน Cloud แทนเครื่องตัวเอง:** ตรวจพบว่าอินเทอร์เน็ตบ้านอยู่หลัง CGNAT (ไม่มี Public IP จึงทำ Port forward ไม่ได้) จึงใช้ EC2 + DuckDNS และเปิดเครื่องเฉพาะช่วงที่ใช้งานเพื่อคุมค่าใช้จ่าย

---

## ข้อจำกัดและแผนต่อยอด

- ใช้ข้อมูลจำลองเท่านั้น การกระจายของข้อมูลไม่สะท้อนการดำเนินงานจริง
- ยังไม่มี CI แผนต่อไปคือ Build และ Test อัตโนมัติทุกครั้งที่เปิด Pull Request
- ระบบภายนอกยังต้องเข้าสู่ระบบด้วยบัญชีผู้ใช้ แผนต่อไปคือออก API Key แยกให้แต่ละระบบ
- [XX]

---

## English summary

Parcel Data Service Hub is a demo system built with **simulated data** for a job interview portfolio.
It is not an official Thailand Post system. Staff can track parcels, view monthly service statistics
and see which parcels are at risk of late delivery. The stack is SQL Server with stored procedures,
an ASP.NET Core REST API with JWT and Swagger, an Angular front end, and a Python (scikit-learn) model
whose predictions are stored in the database. The system is deployed on IIS.

---

## ผู้พัฒนา

[ชื่อ–นามสกุล] · [อีเมล] · [GitHub]

จัดทำเพื่อประกอบการสัมภาษณ์งาน 1 ธันวาคม 2569