import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import {
  BranchDelay, MonthlySummary, ParcelEvent, ParcelSearchResult, StatusCount,
} from './models';

// เรียก API ผ่าน path สัมพัทธ์ /api/v1 — Dev ใช้ proxy.conf.json, Production อยู่เว็บเดียวกับ API
const BASE = '/api/v1';

@Injectable({ providedIn: 'root' })
export class ApiService {
  private readonly http = inject(HttpClient);

  searchParcels(numbers: string[]): Observable<ParcelSearchResult> {
    const params = new HttpParams().set('numbers', numbers.join(','));
    return this.http.get<ParcelSearchResult>(`${BASE}/parcels`, { params });
  }

  parcelEvents(trackingNo: string): Observable<ParcelEvent[]> {
    return this.http.get<ParcelEvent[]>(`${BASE}/parcels/${encodeURIComponent(trackingNo)}/events`);
  }

  monthlySummary(from: string, to: string): Observable<MonthlySummary[]> {
    return this.http.get<MonthlySummary[]>(`${BASE}/stats/summary`, { params: { from, to } });
  }

  statusSummary(from: string, to: string): Observable<StatusCount[]> {
    return this.http.get<StatusCount[]>(`${BASE}/stats/status`, { params: { from, to } });
  }

  branchDelays(from: string, to: string, top = 5): Observable<BranchDelay[]> {
    return this.http.get<BranchDelay[]>(`${BASE}/branches/delays`, { params: { from, to, top } });
  }
}
