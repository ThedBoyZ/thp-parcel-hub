import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-footer',
  imports: [RouterLink],
  template: `
    <footer>
      <div class="container cols">
        <div>
          <h3>เกี่ยวกับโปรเจกต์</h3>
          <p>ระบบตัวอย่างสำหรับให้บริการข้อมูลพัสดุ: SQL Server · ASP.NET Core · Angular · Python ML</p>
        </div>
        <div>
          <h3>รายการที่ใช้ประจำ</h3>
          <ul>
            <li><a routerLink="/">ติดตามพัสดุ</a></li>
            <li><a routerLink="/dashboard">Dashboard</a></li>
            <li><a routerLink="/developers">เอกสาร API</a></li>
          </ul>
        </div>
        <div>
          <h3>สำหรับนักพัฒนา</h3>
          <ul>
            <li><a href="/swagger">Swagger UI</a></li>
            <li><a routerLink="/data-catalog">Data Catalog</a></li>
          </ul>
        </div>
      </div>
      <div class="disclaimer">
        <div class="container">
          © 2026 Demo · โปรเจกต์ส่วนตัวเพื่อประกอบการสัมภาษณ์งาน · ข้อมูลจำลองเพื่อการนำเสนอ | Simulated data
        </div>
      </div>
    </footer>
  `,
  styles: `
    footer { background: var(--bg-soft); margin-top: auto; }
    .cols { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 24px; padding-top: 32px; padding-bottom: 24px; }
    h3 { font-size: 16px; color: var(--navy); }
    p, ul { margin: 0; font-size: 14px; color: var(--muted); }
    ul { list-style: none; padding: 0; display: grid; gap: 6px; }
    a { color: var(--muted); text-decoration: none; }
    a:hover { color: var(--red); }
    .disclaimer { background: var(--red); color: #fff; font-size: 13px; padding: 10px 0; }
  `,
})
export class Footer {}
