import { Component, inject, input, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth.service';
import { Role } from '../../core/models';
import { errorMessage } from '../../core/status';

const DEMO_ACCOUNTS: { username: string; label: string; access: string; home: string; role: Role }[] = [
  { username: 'staff01', label: 'เจ้าหน้าที่', access: 'คาดการณ์ล่าช้า', home: '/delay-risk', role: 'Staff' },
  { username: 'steward01', label: 'ผู้ดูแลข้อมูล', access: '+ Dashboard, ส่งออกข้อมูล', home: '/dashboard', role: 'DataSteward' },
  { username: 'admin01', label: 'ผู้ดูแลระบบ', access: '+ API logs', home: '/dashboard', role: 'Admin' },
];

@Component({
  selector: 'app-login',
  imports: [FormsModule],
  templateUrl: './login.html',
  styleUrl: './login.css',
})
export class Login {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  /** หน้าที่ผู้ใช้ตั้งใจจะเข้า (ส่งมาจาก Guard / Interceptor) */
  readonly returnUrl = input<string>();

  protected readonly accounts = DEMO_ACCOUNTS;
  protected username = '';
  protected password = '';
  protected readonly loading = signal(false);
  protected readonly error = signal<string | null>(null);

  protected fill(username: string): void {
    this.username = username;
    this.password = 'Demo@2026';
    this.error.set(null);
  }

  protected submit(): void {
    if (!this.username || !this.password) {
      this.error.set('กรุณากรอกชื่อผู้ใช้และรหัสผ่าน');
      return;
    }

    this.loading.set(true);
    this.error.set(null);
    this.auth.login(this.username.trim(), this.password).subscribe({
      next: res => {
        const fallback = DEMO_ACCOUNTS.find(a => a.role === res.role)?.home ?? '/';
        this.router.navigateByUrl(this.safeReturnUrl() ?? fallback);
      },
      error: err => {
        this.error.set(errorMessage(err));
        this.loading.set(false);
      },
    });
  }

  // รับเฉพาะ path ภายในเว็บ ป้องกัน Open Redirect (เช่น returnUrl=https://เว็บอื่น)
  private safeReturnUrl(): string | null {
    const url = this.returnUrl();
    return url && url.startsWith('/') && !url.startsWith('//') && !url.startsWith('/login') ? url : null;
  }
}
