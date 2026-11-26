# ER Diagram — Parcel Data Service Hub (ข้อมูลจำลองเพื่อการนำเสนอ)

```mermaid
erDiagram
    Branch   ||--o{ Parcel          : "ต้นทาง (OriginBranchId)"
    Branch   ||--o{ Parcel          : "ปลายทาง (DestBranchId)"
    Customer ||--o{ Parcel          : "ผู้ส่ง (SenderCustomerId)"
    Customer ||--o{ Parcel          : "ผู้รับ (ReceiverCustomerId)"
    Parcel   ||--|{ TrackingEvent   : "มีเหตุการณ์"
    Branch   ||--o{ TrackingEvent   : "เกิดที่สาขา"
    Parcel   ||--o{ DelayPrediction : "ถูกประเมินความเสี่ยง"

    Branch {
        int      BranchId    PK
        varchar  BranchCode  UK
        nvarchar BranchName
        varchar  BranchType  "POST_OFFICE / SORTING_CENTER"
        nvarchar Province
        nvarchar Region
        decimal  Latitude
        decimal  Longitude
    }

    Customer {
        int      CustomerId   PK
        varchar  CustomerCode UK
        nvarchar FullName     "ชื่อจำลอง (Faker)"
        varchar  Phone        "จำลอง, API ส่งแบบปิดบัง"
        nvarchar Province
        varchar  CustomerType "PERSON / BUSINESS"
        datetime2 CreatedAt
    }

    Parcel {
        bigint    ParcelId           PK
        char      TrackingNo         UK "EX123456789TH"
        varchar   ServiceType        "EMS, REG, ECO, ..."
        int       SenderCustomerId   FK
        int       ReceiverCustomerId FK
        int       OriginBranchId     FK
        int       DestBranchId       FK
        int       WeightGram
        decimal   DistanceKm
        datetime2 AcceptedAt         "เวลารับฝาก"
        datetime2 ExpectedDeliveryAt "กำหนดถึง"
        datetime2 DeliveredAt        "NULL = ยังไม่นำจ่าย"
        varchar   CurrentStatus      "สถานะล่าสุด"
        bit       IsDelayed          "computed"
    }

    TrackingEvent {
        bigint    EventId  PK
        bigint    ParcelId FK
        varchar   Status
        int       BranchId FK
        datetime2 EventAt
        nvarchar  Note
    }

    DelayPrediction {
        bigint    PredictionId PK
        int       RunId        "รอบที่รัน predict.py"
        bigint    ParcelId     FK
        decimal   Probability  "0.0000 - 1.0000"
        varchar   RiskLevel    "Low / Medium / High"
        nvarchar  TopFactors   "JSON"
        varchar   ModelVersion
        datetime2 PredictedAt
    }
```

สถานะ (CurrentStatus / Status):

| รหัส | ความหมาย | ลำดับ |
|---|---|---|
| ACCEPTED | รับฝาก | 1 |
| SORTING | คัดแยก | 2 |
| IN_TRANSIT | อยู่ระหว่างขนส่ง | 3 |
| ARRIVED | ถึงที่ทำการ | 4 |
| DELIVERED | นำจ่าย | 5 |
