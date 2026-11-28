import { Component, inject } from '@angular/core';
import { Router, RouterLink, RouterLinkActive } from '@angular/router';
import { AuthService, ROLE_LABEL } from '../core/auth.service';
import { Role } from '../core/models';

interface NavTab {
  path: string;
  label: string;
  minRole?: Role;   // ไม่มี = ทุกคนเข้าได้
}

@Component({
  selector: 'app-header',
  imports: [RouterLink, RouterLinkActive],
  templateUrl: './header.html',
  styleUrl: './header.css',
})
export class Header {
  protected readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  protected readonly roleLabel = ROLE_LABEL;

  protected readonly tabs: NavTab[] = [
    { path: '/', label: 'ติดตามพัสดุ' },
    { path: '/dashboard', label: 'Dashboard', minRole: 'DataSteward' },
    { path: '/delay-risk', label: 'คาดการณ์ล่าช้า', minRole: 'Staff' },
    { path: '/data-catalog', label: 'Data Catalog' },
    { path: '/developers', label: 'สำหรับนักพัฒนา' },
  ];

  // แสดงกุญแจเมื่อแท็บนั้นต้องใช้สิทธิ์ที่ผู้ใช้ยังไม่มี
  protected locked(tab: NavTab): boolean {
    return !!tab.minRole && !this.auth.hasRole(tab.minRole);
  }

  protected logout(): void {
    this.auth.logout();
    this.router.navigateByUrl('/');
  }
}
