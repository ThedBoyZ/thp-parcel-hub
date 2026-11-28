import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService, ROLE_LABEL } from '../core/auth.service';

@Component({
  selector: 'app-forbidden',
  imports: [RouterLink],
  template: `
    <div class="container page center">
      <p class="code">403</p>
      <h1>สิทธิ์ของคุณไม่เพียงพอ</h1>
      <p class="muted">
        บัญชี{{ auth.user() ? roleLabel[auth.user()!.role] : '' }}เข้าหน้านี้ไม่ได้
        — ลองเข้าสู่ระบบด้วยบัญชีที่มีสิทธิ์สูงกว่า
      </p>
      <div class="actions">
        <a routerLink="/" class="btn btn-outline">กลับหน้าแรก</a>
        <a routerLink="/login" class="btn btn-primary">เปลี่ยนบัญชี</a>
      </div>
    </div>
  `,
  styles: `
    .center { text-align: center; padding-top: 64px; }
    .code { font-size: 64px; font-weight: 700; color: var(--red); margin: 0; line-height: 1; }
    .actions { display: flex; gap: 12px; justify-content: center; margin-top: 24px; }
  `,
})
export class Forbidden {
  protected readonly auth = inject(AuthService);
  protected readonly roleLabel = ROLE_LABEL;
}
