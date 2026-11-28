// รูปแบบข้อมูลจาก API (/api/v1) — ชื่อ field ตรงกับ JSON (camelCase)

export type ParcelStatus = 'ACCEPTED' | 'SORTING' | 'IN_TRANSIT' | 'ARRIVED' | 'DELIVERED';
export type Role = 'Staff' | 'DataSteward' | 'Admin';

export interface ParcelDetail {
  trackingNo: string;
  serviceType: string;
  currentStatus: ParcelStatus;
  weightGram: number;
  acceptedAt: string;
  expectedDeliveryAt: string;
  deliveredAt: string | null;
  isDelayed: boolean | null;
  originBranch: string;
  originProvince: string;
  destBranch: string;
  destProvince: string;
}

export interface ParcelEvent {
  eventAt: string;
  status: ParcelStatus;
  branchName: string;
  province: string;
  note: string | null;
}

export interface ParcelSearchResult {
  found: ParcelDetail[];
  notFound: string[];
}

export interface LoginResponse {
  token: string;
  expiresIn: number;
  role: Role;
  displayName: string;
}

export interface MonthlySummary {
  month: string;
  totalParcels: number;
  deliveredParcels: number;
  delayedParcels: number;
  onTimeRate: number | null;
  avgDeliveryDays: number | null;
}

export interface StatusCount {
  status: ParcelStatus;
  parcels: number;
  delayedParcels: number;
}

export interface BranchDelay {
  branchCode: string;
  branchName: string;
  province: string;
  deliveredParcels: number;
  delayedParcels: number;
  delayRate: number;
}

// ProblemDetails (RFC 9457) ที่ API ตอบเมื่อเกิด Error
export interface ProblemDetails {
  status?: number;
  title?: string;
  detail?: string;
  errors?: Record<string, string[]>;
}
