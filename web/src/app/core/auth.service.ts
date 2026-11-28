import { HttpClient } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { LoginResponse, Role } from './models';

interface Session {
  token: string;
  role: Role;
  displayName: string;
  expiresAt: number;   // epoch ms
}

const STORAGE_KEY = 'parcelhub.session';

// สิทธิ์เป็นลำดับขั้น: Admin ⊃ DataSteward ⊃ Staff (ตรงกับ Policy ฝั่ง API)
const ROLE_RANK: Record<Role, number> = { Staff: 1, DataSteward: 2, Admin: 3 };

export const ROLE_LABEL: Record<Role, string> = {
  Staff: 'เจ้าหน้าที่',
  DataSteward: 'ผู้ดูแลข้อมูล',
  Admin: 'ผู้ดูแลระบบ',
};

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly session = signal<Session | null>(this.restore());

  readonly user = computed(() => this.session());
  readonly isLoggedIn = computed(() => this.session() !== null);

  login(username: string, password: string): Observable<LoginResponse> {
    return this.http.post<LoginResponse>('/api/v1/auth/login', { username, password }).pipe(
      tap(res => this.save({
        token: res.token,
        role: res.role,
        displayName: res.displayName,
        expiresAt: Date.now() + res.expiresIn * 1000,
      })),
    );
  }

  logout(): void {
    this.session.set(null);
    try { sessionStorage.removeItem(STORAGE_KEY); } catch { /* storage ปิดอยู่ */ }
  }

  /** Token ที่ยังไม่หมดอายุ — หมดอายุแล้วออกจากระบบให้อัตโนมัติ */
  token(): string | null {
    const s = this.session();
    if (!s) return null;
    if (Date.now() >= s.expiresAt) {
      this.logout();
      return null;
    }
    return s.token;
  }

  hasRole(min: Role): boolean {
    const s = this.session();
    return !!s && Date.now() < s.expiresAt && ROLE_RANK[s.role] >= ROLE_RANK[min];
  }

  // เก็บใน sessionStorage: ปิดแท็บแล้วหลุด (ลดความเสี่ยง Token ค้างในเครื่องสาธารณะ)
  private save(s: Session): void {
    this.session.set(s);
    try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify(s)); } catch { /* storage ปิดอยู่ */ }
  }

  private restore(): Session | null {
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      const s = JSON.parse(raw) as Session;
      return Date.now() < s.expiresAt ? s : null;
    } catch {
      return null;
    }
  }
}
