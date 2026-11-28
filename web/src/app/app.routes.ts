import { Routes } from '@angular/router';
import { roleGuard } from './core/role.guard';

// สิทธิ์ตาม README: ไม่ต้อง Login → หน้าแรก / Data Catalog / นักพัฒนา
//                   เจ้าหน้าที่ขึ้นไป → คาดการณ์ล่าช้า · ผู้ดูแลข้อมูลขึ้นไป → Dashboard
export const routes: Routes = [
  { path: '', title: 'ติดตามพัสดุ · Parcel Data Service Hub',
    loadComponent: () => import('./pages/home/home').then(m => m.Home) },
  { path: 'login', title: 'เข้าสู่ระบบ · Parcel Data Service Hub',
    loadComponent: () => import('./pages/login/login').then(m => m.Login) },
  { path: 'dashboard', title: 'Dashboard · Parcel Data Service Hub',
    canActivate: [roleGuard('DataSteward')],
    loadComponent: () => import('./pages/dashboard/dashboard').then(m => m.Dashboard) },
  { path: 'delay-risk', title: 'คาดการณ์ล่าช้า · Parcel Data Service Hub',
    canActivate: [roleGuard('Staff')],
    loadComponent: () => import('./pages/placeholder').then(m => m.Placeholder),
    data: { heading: 'คาดการณ์ความเสี่ยงล่าช้า' } },
  { path: 'data-catalog', title: 'Data Catalog · Parcel Data Service Hub',
    loadComponent: () => import('./pages/placeholder').then(m => m.Placeholder),
    data: { heading: 'Data Catalog' } },
  { path: 'developers', title: 'สำหรับนักพัฒนา · Parcel Data Service Hub',
    loadComponent: () => import('./pages/placeholder').then(m => m.Placeholder),
    data: { heading: 'สำหรับนักพัฒนา' } },
  { path: 'forbidden', title: 'ไม่มีสิทธิ์เข้าถึง · Parcel Data Service Hub',
    loadComponent: () => import('./pages/forbidden').then(m => m.Forbidden) },
  { path: '**', redirectTo: '' },
];
