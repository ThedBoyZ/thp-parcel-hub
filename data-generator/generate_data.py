"""
generate_data.py — สร้างข้อมูลจำลองลง SQL Server (ParcelHubDemo)
ข้อมูลจำลองเพื่อการนำเสนอ (Simulated data) — ไม่ใช่ข้อมูลจริงของ บริษัท ไปรษณีย์ไทย จำกัด

ต้องรัน database/01_schema.sql ก่อน
รันซ้ำได้: ลบข้อมูลเดิมทั้งหมดแล้วสร้างใหม่ ได้ผลเหมือนเดิมทุกครั้ง (fixed seed)

    python generate_data.py                      # ค่าเริ่มต้น 100,000 พัสดุ
    python generate_data.py --parcels 1000       # ทดลองเร็ว ๆ
"""

import argparse
import math
import random
import time
from datetime import datetime, timedelta

import pyodbc
from faker import Faker

# ---------------------------------------------------------------------
# ค่าตั้งต้น
# ---------------------------------------------------------------------
SEED = 42                                   # ★ ใช้ seed เดิม = รันกี่ครั้งก็ได้ข้อมูลชุดเดิม
START = datetime(2026, 1, 1)
AS_OF = datetime(2026, 11, 30, 18, 0)       # "วันนี้" ของข้อมูลจำลอง (ตายตัว ไม่ใช้ datetime.now())

DEFAULT_CONN = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=.\\SQLEXPRESS;DATABASE=ParcelHubDemo;"
    "Trusted_Connection=yes;TrustServerCertificate=yes;"
)

# จังหวัด, ภาค, ละติจูด, ลองจิจูด, จำนวนที่ทำการ (พิกัดโดยประมาณของตัวจังหวัด)
PROVINCES = [
    ("กรุงเทพมหานคร", "ภาคกลาง", 13.7563, 100.5018, 3),
    ("นนทบุรี", "ภาคกลาง", 13.8621, 100.5144, 1),
    ("ปทุมธานี", "ภาคกลาง", 14.0208, 100.5250, 1),
    ("พระนครศรีอยุธยา", "ภาคกลาง", 14.3532, 100.5689, 1),
    ("นครปฐม", "ภาคกลาง", 13.8199, 100.0621, 1),
    ("เชียงใหม่", "ภาคเหนือ", 18.7883, 98.9853, 2),
    ("เชียงราย", "ภาคเหนือ", 19.9105, 99.8406, 1),
    ("ลำปาง", "ภาคเหนือ", 18.2888, 99.4908, 1),
    ("พิษณุโลก", "ภาคเหนือ", 16.8211, 100.2659, 1),
    ("นครสวรรค์", "ภาคเหนือ", 15.7047, 100.1372, 1),
    ("ขอนแก่น", "ภาคอีสาน", 16.4322, 102.8236, 2),
    ("นครราชสีมา", "ภาคอีสาน", 14.9799, 102.0978, 2),
    ("อุดรธานี", "ภาคอีสาน", 17.4156, 102.7872, 1),
    ("อุบลราชธานี", "ภาคอีสาน", 15.2448, 104.8473, 1),
    ("ชลบุรี", "ภาคตะวันออก", 13.3611, 100.9847, 2),
    ("ระยอง", "ภาคตะวันออก", 12.6814, 101.2816, 1),
    ("จันทบุรี", "ภาคตะวันออก", 12.6113, 102.1039, 1),
    ("กาญจนบุรี", "ภาคตะวันตก", 14.0228, 99.5328, 1),
    ("ราชบุรี", "ภาคตะวันตก", 13.5283, 99.8134, 1),
    ("สุราษฎร์ธานี", "ภาคใต้", 9.1382, 99.3215, 1),
    ("ภูเก็ต", "ภาคใต้", 7.8804, 98.3923, 1),
    ("สงขลา", "ภาคใต้", 7.1898, 100.5951, 2),
    ("นครศรีธรรมราช", "ภาคใต้", 8.4304, 99.9631, 1),
]

# ศูนย์คัดแยก 1 แห่งต่อภาค (ตั้งอยู่ที่จังหวัดไหน)
SORTING_CENTER_AT = {
    "ภาคกลาง": "กรุงเทพมหานคร",
    "ภาคเหนือ": "พิษณุโลก",
    "ภาคอีสาน": "ขอนแก่น",
    "ภาคตะวันออก": "ชลบุรี",
    "ภาคตะวันตก": "ราชบุรี",
    "ภาคใต้": "สุราษฎร์ธานี",
}

# บริการ: (ตัวอักษรนำหน้าเลขพัสดุ, SLA วัน, สัดส่วน, โอกาสล่าช้าพื้นฐาน)
SERVICES = {
    "EMS":     ("EX", 1, 0.35, 0.06),
    "REG":     ("RX", 3, 0.20, 0.10),
    "ECO":     ("EC", 5, 0.15, 0.15),
    "LOGIS":   ("LG", 3, 0.08, 0.12),
    "COD":     ("CD", 3, 0.15, 0.10),
    "EMSW":    ("EW", 5, 0.03, 0.12),
    "COURIER": ("CP", 4, 0.02, 0.10),
    "INTL":    ("CX", 10, 0.02, 0.20),
}

# ปริมาณพัสดุแต่ละเดือน (ม.ค.–พ.ย.) ต.ค. สูงสุดตามดีไซน์ Dashboard
MONTH_WEIGHT = [0.80, 0.75, 0.80, 0.85, 0.90, 0.85, 0.90, 0.95, 0.90, 1.15, 1.10]

# ชั่วโมงที่รับฝาก 08:00–18:00 (ช่วงสายและบ่ายค่อนเย็นคนเยอะ)
HOURS = list(range(8, 19))
HOUR_WEIGHT = [3, 6, 8, 8, 5, 6, 7, 8, 6, 4, 2]

# จำนวนสาขาที่ "มีปัญหา" ส่งช้ากว่าปกติ (ให้หน้า Dashboard มีอันดับสาขาล่าช้า)
BAD_BRANCH_COUNT = 4

# เลขพัสดุสำหรับ demo — ครบทั้ง 5 สถานะ ค้นหาจากหน้า Home ได้จริง
# (เลขพัสดุ, สถานะที่ต้องการ, ล่าช้าไหม — None = ยังไม่นำจ่าย)
DEMO_PARCELS = [
    ("EX987654321TH", "ACCEPTED", None),
    ("EX555000111TH", "SORTING", None),
    ("EX123456789TH", "IN_TRANSIT", None),
    ("EX246813579TH", "ARRIVED", None),
    ("EX112233445TH", "DELIVERED", False),   # นำจ่ายตรงเวลา
    ("EX998877665TH", "DELIVERED", True),    # นำจ่ายแต่ล่าช้า
]
DEMO_TRACKING_NOS = [d[0] for d in DEMO_PARCELS]

# ลำดับสถานะ และ "ช่วงเวลา" ที่สถานะนั้นเกิด (สัดส่วนของเวลานำส่งทั้งหมด)
STATUS_STEPS = [
    ("ACCEPTED", 0.00),
    ("SORTING", 0.15),
    ("IN_TRANSIT", 0.35),
    ("ARRIVED", 0.80),
    ("DELIVERED", 1.00),
]


# ---------------------------------------------------------------------
# ฟังก์ชันช่วย
# ---------------------------------------------------------------------
def trim(dt):
    """ตัดเศษวินาที ให้ตรงกับ DATETIME2(0) ในฐานข้อมูล"""
    return dt.replace(microsecond=0)


def distance_km(a, b):
    """ระยะทางระหว่าง 2 สาขา (เส้นตรงบนผิวโลก x 1.25 ให้ใกล้ระยะถนน)"""
    lat1, lon1, lat2, lon2 = map(math.radians, (a["lat"], a["lon"], b["lat"], b["lon"]))
    h = (math.sin((lat2 - lat1) / 2) ** 2
         + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2)
    km = 2 * 6371 * math.asin(math.sqrt(h)) * 1.25
    return round(max(km, random.uniform(3, 25)), 1)   # สาขาในจังหวัดเดียวกัน อย่างน้อย 3 กม.


# ---------------------------------------------------------------------
# 1) Branch
# ---------------------------------------------------------------------
def make_branches():
    branches = []
    for province, region, lat, lon, count in PROVINCES:
        for n in range(1, count + 1):
            branches.append({
                "id": len(branches) + 1,
                "code": f"BR{len(branches) + 1:03d}",
                "name": f"ที่ทำการฯ {province} {n}" if count > 1 else f"ที่ทำการฯ {province}",
                "type": "POST_OFFICE",
                "province": province,
                "region": region,
                "lat": round(lat + random.uniform(-0.05, 0.05), 6),
                "lon": round(lon + random.uniform(-0.05, 0.05), 6),
            })

    lookup = {p[0]: p for p in PROVINCES}
    for i, (region, province) in enumerate(SORTING_CENTER_AT.items(), start=1):
        _, _, lat, lon, _ = lookup[province]
        branches.append({
            "id": len(branches) + 1,
            "code": f"SC{i:02d}",
            "name": f"ศูนย์คัดแยก{region}",
            "type": "SORTING_CENTER",
            "province": province,
            "region": region,
            "lat": lat,
            "lon": lon,
        })
    return branches


# ---------------------------------------------------------------------
# 2) Customer — ชื่อและเบอร์โทรจาก Faker ทั้งหมด (ไม่มีข้อมูลบุคคลจริง: PDPA)
# ---------------------------------------------------------------------
def make_customers(fake, n):
    customers = []
    for i in range(1, n + 1):
        is_business = random.random() < 0.10
        customers.append({
            "id": i,
            "code": f"C{i:06d}",
            "name": fake.company() if is_business else fake.name(),
            "phone": "0" + random.choice("689") + "".join(random.choices("0123456789", k=8)),
            "province": random.choice(PROVINCES)[0],
            "type": "BUSINESS" if is_business else "PERSON",
            "created": trim(START - timedelta(days=random.randint(0, 700))),
        })
    return customers


# ---------------------------------------------------------------------
# 3) Parcel
# ---------------------------------------------------------------------
def random_accepted_times(n):
    """สุ่มเวลารับฝาก n ครั้ง ตามน้ำหนักเดือน / วันในสัปดาห์ / ชั่วโมง แล้วเรียงตามเวลา"""
    days, weights = [], []
    day = START
    while day.date() <= AS_OF.date():
        w = MONTH_WEIGHT[day.month - 1]
        if day.weekday() == 6:      # อาทิตย์ คนน้อย
            w *= 0.4
        elif day.weekday() == 5:    # เสาร์
            w *= 0.7
        days.append(day)
        weights.append(w)
        day += timedelta(days=1)

    times = []
    for d in random.choices(days, weights=weights, k=n):
        t = d.replace(hour=random.choices(HOURS, weights=HOUR_WEIGHT)[0],
                      minute=random.randint(0, 59), second=random.randint(0, 59))
        if t > AS_OF:
            t = AS_OF - timedelta(minutes=random.randint(1, 600))
        times.append(t)
    return sorted(times)


def delay_probability(service, km, weight_g, hour, bad_origin, month):
    """
    ตรงนี้สำคัญ: "กติกา" ที่ทำให้พัสดุล่าช้า
    โมเดล ML ในขั้น ml/ จะต้องเรียนรู้กติกานี้กลับมาเองจากข้อมูล
    ปัจจัยตรงกับที่หน้า DelayRisk แสดง: ระยะทาง / ช่วงเวลารับฝาก / สาขาต้นทาง / น้ำหนัก
    """
    p = SERVICES[service][3]
    p += km / 1000 * 0.15                  # ไกล 1,000 กม. เสี่ยงเพิ่ม 15%
    p += 0.05 if weight_g > 5000 else 0    # หนักเกิน 5 กก.
    p += 0.08 if hour >= 15 else 0         # รับฝากบ่ายค่อนเย็น ตกรอบรถ
    p += 0.12 if bad_origin else 0         # สาขาต้นทางที่มีปัญหา
    p += 0.05 if month in (10, 11) else 0  # ช่วงพีค เดือน ตุลาคม และ พฤศจิกายน
    return min(p, 0.85)


def make_tracking_no(prefix, used):
    while True:
        no = f"{prefix}{random.randint(0, 999_999_999):09d}TH"
        if no not in used:
            used.add(no)
            return no


def make_parcels(n, branches, customers):
    post_offices = [b for b in branches if b["type"] == "POST_OFFICE"]
    po_weight = [3 if b["province"] == "กรุงเทพมหานคร" else 1 for b in post_offices]
    bad_ids = {b["id"] for b in random.sample(post_offices, BAD_BRANCH_COUNT)}

    service_codes = list(SERVICES)
    service_share = [SERVICES[s][2] for s in service_codes]
    used = set(DEMO_TRACKING_NOS)          # กันไม่ให้สุ่มชนกับเลข demo

    parcels = []
    for i, accepted in enumerate(random_accepted_times(n), start=1):
        service = random.choices(service_codes, weights=service_share)[0]
        prefix, sla_days, _, _ = SERVICES[service]

        origin = random.choices(post_offices, weights=po_weight)[0]
        dest = random.choice(post_offices)
        while dest["id"] == origin["id"]:
            dest = random.choice(post_offices)

        sender = random.choice(customers)
        receiver = random.choice(customers)
        while receiver["id"] == sender["id"]:
            receiver = random.choice(customers)

        km = distance_km(origin, dest)
        weight_g = int(min(30_000, max(50, random.lognormvariate(7.0, 1.0))))   # ส่วนใหญ่ ~1 กก.
        expected = (accepted + timedelta(days=sla_days)).replace(hour=20, minute=0, second=0)

        # ตัดสินว่าชิ้นนี้ "จะ" ล่าช้าหรือไม่ แล้วกำหนดเวลานำจ่ายตามนั้น
        p = delay_probability(service, km, weight_g, accepted.hour,
                              origin["id"] in bad_ids, accepted.month)
        if random.random() < p:
            finish = expected + timedelta(hours=random.uniform(3, 60))
        else:
            finish = accepted + (expected - accepted) * random.uniform(0.45, 0.98)

        parcels.append({
            "id": i,
            "tracking_no": make_tracking_no(prefix, used),
            "service": service,
            "sender": sender["id"],
            "receiver": receiver["id"],
            "origin": origin,
            "dest": dest,
            "weight": weight_g,
            "km": km,
            "accepted": trim(accepted),
            "expected": trim(expected),
            "finish": trim(finish),      # เวลานำจ่าย "ตามแผน" (อาจอยู่หลัง AS_OF = ยังไม่ถึง)
        })
    return parcels


# ---------------------------------------------------------------------
# 4) TrackingEvent — สร้างเฉพาะเหตุการณ์ที่เกิดขึ้นแล้ว (เวลา <= AS_OF)
# ---------------------------------------------------------------------
def make_events(parcels, branches):
    center = {b["region"]: b for b in branches if b["type"] == "SORTING_CENTER"}
    events = []
    for p in parcels:
        where = {
            "ACCEPTED": p["origin"],
            "SORTING": center[p["origin"]["region"]],
            "IN_TRANSIT": center[p["dest"]["region"]],
            "ARRIVED": p["dest"],
            "DELIVERED": p["dest"],
        }
        total = p["finish"] - p["accepted"]
        status = "ACCEPTED"
        for step, frac in STATUS_STEPS:
            at = trim(p["accepted"] + total * frac)
            if at > AS_OF:
                break
            events.append((p["id"], step, where[step]["id"], at, None))
            status = step

        # เก็บสถานะล่าสุดไว้ใน Parcel ด้วย (Denormalize) ให้หน้าติดตามอ่านได้ทันที
        p["status"] = status
        p["delivered"] = p["finish"] if status == "DELIVERED" else None
    return events


def assign_demo_numbers(parcels):
    """หาพัสดุ EMS ล่าสุดที่มีสถานะตรงตาม DEMO_PARCELS แล้วเปลี่ยนเลขเป็นเลข demo"""
    taken = set()
    for no, status, late in DEMO_PARCELS:
        for p in reversed(parcels):                 # ไล่จากชิ้นล่าสุด
            if p["id"] in taken or p["service"] != "EMS" or p["status"] != status:
                continue
            if late is not None and (p["delivered"] > p["expected"]) != late:
                continue
            p["tracking_no"] = no
            taken.add(p["id"])
            break
        else:
            raise RuntimeError(f"ไม่พบพัสดุสถานะ {status} สำหรับเลข demo {no}")


# ---------------------------------------------------------------------
# 5) เขียนลงฐานข้อมูล
# ---------------------------------------------------------------------
def clear_tables(cur):
    # ลบ "ลูก" ก่อน "แม่" เพราะติด Foreign Key (ลำดับเดียวกับ 01_schema.sql)
    cur.execute("TRUNCATE TABLE dbo.DelayPrediction")
    cur.execute("TRUNCATE TABLE dbo.TrackingEvent")
    for table in ("Parcel", "Customer", "Branch"):
        cur.execute(f"DELETE FROM dbo.{table}")


def bulk_insert(cur, table, columns, rows, batch=20_000):
    """
    ตรงนี้สำคัญ: fast_executemany ส่งข้อมูลเป็นก้อน แทนการยิง INSERT ทีละแถว
    100,000 แถว เหลือไม่กี่วินาที (ทีละแถวใช้หลายนาที)
    IDENTITY_INSERT ON = ใส่เลข Id เองได้ จึงรู้ล่วงหน้าว่าพัสดุชิ้นไหน Id อะไร
    """
    has_identity = table != "TrackingEvent"
    sql = (f"INSERT INTO dbo.{table} ({', '.join(columns)}) "
           f"VALUES ({', '.join('?' * len(columns))})")
    if has_identity:
        cur.execute(f"SET IDENTITY_INSERT dbo.{table} ON")
    cur.fast_executemany = True
    for start in range(0, len(rows), batch):
        cur.executemany(sql, rows[start:start + batch])
        print(f"  {table}: {min(start + batch, len(rows)):,} / {len(rows):,}", end="\r")
    print()
    if has_identity:
        cur.execute(f"SET IDENTITY_INSERT dbo.{table} OFF")


def save(conn, branches, customers, parcels, events):
    cur = conn.cursor()
    clear_tables(cur)

    bulk_insert(cur, "Branch",
                ["BranchId", "BranchCode", "BranchName", "BranchType",
                 "Province", "Region", "Latitude", "Longitude"],
                [(b["id"], b["code"], b["name"], b["type"],
                  b["province"], b["region"], b["lat"], b["lon"]) for b in branches])

    bulk_insert(cur, "Customer",
                ["CustomerId", "CustomerCode", "FullName", "Phone",
                 "Province", "CustomerType", "CreatedAt"],
                [(c["id"], c["code"], c["name"], c["phone"],
                  c["province"], c["type"], c["created"]) for c in customers])

    bulk_insert(cur, "Parcel",
                ["ParcelId", "TrackingNo", "ServiceType", "SenderCustomerId",
                 "ReceiverCustomerId", "OriginBranchId", "DestBranchId", "WeightGram",
                 "DistanceKm", "AcceptedAt", "ExpectedDeliveryAt", "DeliveredAt", "CurrentStatus"],
                [(p["id"], p["tracking_no"], p["service"], p["sender"],
                  p["receiver"], p["origin"]["id"], p["dest"]["id"], p["weight"],
                  p["km"], p["accepted"], p["expected"], p["delivered"], p["status"])
                 for p in parcels])

    bulk_insert(cur, "TrackingEvent",
                ["ParcelId", "Status", "BranchId", "EventAt", "Note"], events)

    conn.commit()     # ทั้งหมดอยู่ใน Transaction เดียว — พังกลางทาง ไม่มีข้อมูลครึ่ง ๆ ค้าง


# ---------------------------------------------------------------------
# main
# ---------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="สร้างข้อมูลจำลองลง ParcelHubDemo")
    parser.add_argument("--parcels", type=int, default=100_000)
    parser.add_argument("--customers", type=int, default=20_000)
    parser.add_argument("--conn", default=DEFAULT_CONN, help="ODBC connection string")
    args = parser.parse_args()

    random.seed(SEED)
    Faker.seed(SEED)
    fake = Faker("th_TH")

    t0 = time.time()
    print("กำลังสร้างข้อมูล ...")
    branches = make_branches()
    customers = make_customers(fake, args.customers)
    parcels = make_parcels(args.parcels, branches, customers)
    events = make_events(parcels, branches)
    assign_demo_numbers(parcels)

    print("กำลังบันทึกลง SQL Server ...")
    with pyodbc.connect(args.conn, autocommit=False) as conn:
        save(conn, branches, customers, parcels, events)

    delivered = [p for p in parcels if p["delivered"]]
    late = sum(p["delivered"] > p["expected"] for p in delivered)
    print(f"\nเสร็จใน {time.time() - t0:.1f} วินาที")
    print(f"  สาขา {len(branches):,} | ลูกค้า {len(customers):,} | "
          f"พัสดุ {len(parcels):,} | เหตุการณ์ {len(events):,}")
    print(f"  นำจ่ายแล้ว {len(delivered):,} (ล่าช้า {late / len(delivered):.1%}) | "
          f"ยังไม่นำจ่าย {len(parcels) - len(delivered):,}")
    print("  เลขพัสดุ demo:")
    for no, status, late in DEMO_PARCELS:
        print(f"    {no}  {status}{' (ล่าช้า)' if late else ''}")


if __name__ == "__main__":
    main()
