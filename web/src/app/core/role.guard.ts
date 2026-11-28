import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';
import { Role } from './models';

// กันเข้าหน้าโดยตรงจาก URL — ยังไม่ Login → หน้า Login, สิทธิ์ไม่พอ → หน้า 403
// (เป็นด่านฝั่ง UI เท่านั้น ด่านจริงคือ [Authorize] ที่ API)
export function roleGuard(min: Role): CanActivateFn {
  return (_route, state) => {
    const auth = inject(AuthService);
    const router = inject(Router);

    if (!auth.isLoggedIn() || !auth.token()) {
      return router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
    }
    return auth.hasRole(min) ? true : router.createUrlTree(['/forbidden']);
  };
}
