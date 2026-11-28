import { HttpErrorResponse } from '@angular/common/http';
import { ParcelStatus, ProblemDetails } from './models';

// ลำดับสถานะพัสดุ 5 ขั้น (ตรงกับ CHECK ใน 01_schema.sql)
export const STATUS_STEPS: { code: ParcelStatus; label: string }[] = [
  { code: 'ACCEPTED', label: 'รับฝาก' },
  { code: 'SORTING', label: 'คัดแยก' },
  { code: 'IN_TRANSIT', label: 'ระหว่างขนส่ง' },
  { code: 'ARRIVED', label: 'ถึงที่ทำการปลายทาง' },
  { code: 'DELIVERED', label: 'นำจ่ายสำเร็จ' },
];

export function statusLabel(code: string): string {
  return STATUS_STEPS.find(s => s.code === code)?.label ?? code;
}

export function statusIndex(code: string): number {
  return STATUS_STEPS.findIndex(s => s.code === code);
}

// แปลง Error จาก API (ProblemDetails) เป็นข้อความภาษาไทยสำหรับแสดงผล
export function errorMessage(err: unknown): string {
  if (err instanceof HttpErrorResponse) {
    if (err.status === 0) return 'เชื่อมต่อ API ไม่ได้ กรุณาลองใหม่อีกครั้ง';
    const problem = err.error as ProblemDetails | null;
    if (err.status === 429) return problem?.title ?? 'เรียกใช้งานถี่เกินกำหนด กรุณารอสักครู่';
    if (problem?.title) return problem.detail ? `${problem.title}: ${problem.detail}` : problem.title;
    return `เกิดข้อผิดพลาด (${err.status})`;
  }
  return 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ';
}
