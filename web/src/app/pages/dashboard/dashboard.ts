import { DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { forkJoin } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { BranchDelay, MonthlySummary, StatusCount } from '../../core/models';
import { STATUS_STEPS, errorMessage, statusLabel } from '../../core/status';

const THAI_MONTHS = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

// ข้อมูลจำลองครอบคลุม 1 ม.ค. – 30 พ.ย. 2026
const PRESETS = [
  { label: 'ม.ค. – พ.ย. 2026', from: '2026-01-01', to: '2026-11-30' },
  { label: 'ไตรมาสล่าสุด', from: '2026-09-01', to: '2026-11-30' },
  { label: 'พ.ย. 2026', from: '2026-11-01', to: '2026-11-30' },
];

// ขนาดกราฟ (หน่วย viewBox) — SVG ย่อขยายตามความกว้างการ์ด
const W = 640, H = 240, PAD = { top: 16, right: 16, bottom: 28, left: 52 };

interface Bar { x: number; y: number; w: number; h: number; path: string; label: string; m: MonthlySummary }
interface Point { x: number; y: number; label: string; m: MonthlySummary }

@Component({
  selector: 'app-dashboard',
  imports: [FormsModule, RouterLink, DecimalPipe],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.css',
})
export class Dashboard {
  private readonly api = inject(ApiService);

  protected readonly presets = PRESETS;
  protected readonly statusLabel = statusLabel;
  protected readonly W = W;
  protected readonly H = H;
  protected readonly PAD = PAD;

  protected from = PRESETS[0].from;
  protected to = PRESETS[0].to;
  protected readonly loading = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly monthly = signal<MonthlySummary[]>([]);
  protected readonly statuses = signal<StatusCount[]>([]);
  protected readonly branches = signal<BranchDelay[]>([]);
  protected readonly showTable = signal(false);
  protected readonly hover = signal<number | null>(null);   // index เดือนที่ชี้อยู่ (ใช้ร่วมทั้ง 2 กราฟ)

  // ---- KPI รวมทั้งช่วง (ถ่วงน้ำหนักตามจำนวนพัสดุ ไม่ใช่เฉลี่ยของค่าเฉลี่ย) ----
  protected readonly kpi = computed(() => {
    const rows = this.monthly();
    const total = rows.reduce((s, r) => s + r.totalParcels, 0);
    const delivered = rows.reduce((s, r) => s + r.deliveredParcels, 0);
    const delayed = rows.reduce((s, r) => s + r.delayedParcels, 0);
    const dayWeighted = rows.reduce((s, r) => s + (r.avgDeliveryDays ?? 0) * r.deliveredParcels, 0);
    return {
      total,
      delivered,
      onTimeRate: delivered ? (100 * (delivered - delayed)) / delivered : null,
      avgDays: delivered ? dayWeighted / delivered : null,
    };
  });

  // ---- กราฟแท่ง: จำนวนพัสดุรายเดือน ----
  protected readonly barChart = computed(() => {
    const rows = this.monthly();
    const max = niceMax(Math.max(0, ...rows.map(r => r.totalParcels)));
    const plotW = W - PAD.left - PAD.right, plotH = H - PAD.top - PAD.bottom;
    const band = rows.length ? plotW / rows.length : 0;
    const barW = Math.min(24, band * 0.6);

    const bars: Bar[] = rows.map((m, i) => {
      const h = max ? (m.totalParcels / max) * plotH : 0;
      const x = PAD.left + band * i + (band - barW) / 2;
      const y = PAD.top + plotH - h;
      return { x, y, w: barW, h, path: roundedTop(x, y, barW, h, 4), label: monthLabel(m.month), m };
    });
    return { bars, ticks: ticks(max, 4).map(v => ({ v, y: PAD.top + plotH - (max ? (v / max) * plotH : 0) })), band };
  });

  // ---- กราฟเส้น: อัตราส่งตรงเวลา (%) รายเดือน — แยกกราฟ ไม่ใช้แกน Y สองข้าง ----
  protected readonly lineChart = computed(() => {
    const rows = this.monthly().filter(r => r.onTimeRate !== null);
    const all = this.monthly();
    const plotW = W - PAD.left - PAD.right, plotH = H - PAD.top - PAD.bottom;
    const band = all.length ? plotW / all.length : 0;
    const values = rows.map(r => r.onTimeRate!);
    const lo = Math.max(0, Math.floor((Math.min(100, ...values) - 5) / 5) * 5);
    const hi = Math.min(100, Math.ceil((Math.max(0, ...values) + 5) / 5) * 5);
    const scaleY = (v: number) => PAD.top + plotH - ((v - lo) / (hi - lo || 1)) * plotH;

    const points: Point[] = rows.map(m => ({
      x: PAD.left + band * all.indexOf(m) + band / 2,
      y: scaleY(m.onTimeRate!),
      label: monthLabel(m.month),
      m,
    }));
    const path = points.map((p, i) => `${i ? 'L' : 'M'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ');
    const step = (hi - lo) / 4;
    return {
      points, path, band,
      ticks: [0, 1, 2, 3, 4].map(k => ({ v: lo + step * k, y: scaleY(lo + step * k) })),
    };
  });

  // ---- แถบจำนวนพัสดุตามสถานะ (เรียงตาม 5 ขั้น) ----
  protected readonly statusBars = computed(() => {
    const rows = this.statuses();
    const max = Math.max(1, ...rows.map(r => r.parcels));
    return STATUS_STEPS.map(s => {
      const row = rows.find(r => r.status === s.code);
      const parcels = row?.parcels ?? 0;
      return { label: s.label, parcels, pct: (parcels / max) * 100 };
    });
  });

  constructor() {
    this.load();
  }

  protected applyPreset(p: { from: string; to: string }): void {
    this.from = p.from;
    this.to = p.to;
    this.load();
  }

  protected isPreset(p: { from: string; to: string }): boolean {
    return this.from === p.from && this.to === p.to;
  }

  // เรียก 3 endpoint พร้อมกัน (forkJoin) แล้วรอให้ครบก่อนแสดงผล
  protected load(): void {
    if (!this.from || !this.to) return;
    if (this.from > this.to) {
      this.error.set('วันที่เริ่มต้องไม่มากกว่าวันที่สิ้นสุด');
      return;
    }

    this.loading.set(true);
    this.error.set(null);
    forkJoin({
      monthly: this.api.monthlySummary(this.from, this.to),
      statuses: this.api.statusSummary(this.from, this.to),
      branches: this.api.branchDelays(this.from, this.to, 5),
    }).subscribe({
      next: res => {
        this.monthly.set(res.monthly);
        this.statuses.set(res.statuses);
        this.branches.set(res.branches);
        this.loading.set(false);
      },
      error: err => {
        this.error.set(errorMessage(err));
        this.loading.set(false);
      },
    });
  }

  protected monthLabel = monthLabel;

  // ส่งออกเป็น CSV (UTF-8 BOM) — เปิดใน Excel แล้วภาษาไทยไม่เพี้ยน
  protected exportCsv(): void {
    const lines: (string | number)[][] = [
      [`รายงานสรุปพัสดุ ${this.from} ถึง ${this.to} (ข้อมูลจำลอง)`],
      [],
      ['เดือน', 'พัสดุทั้งหมด', 'นำจ่ายแล้ว', 'ล่าช้า', 'อัตราตรงเวลา (%)', 'เวลานำส่งเฉลี่ย (วัน)'],
      ...this.monthly().map(m => [m.month, m.totalParcels, m.deliveredParcels, m.delayedParcels, m.onTimeRate ?? '', m.avgDeliveryDays ?? '']),
      [],
      ['สถานะ', 'จำนวนพัสดุ'],
      ...this.statusBars().map(s => [s.label, s.parcels]),
      [],
      ['รหัสสาขา', 'สาขา', 'จังหวัด', 'นำจ่ายแล้ว', 'ล่าช้า', 'อัตราล่าช้า (%)'],
      ...this.branches().map(b => [b.branchCode, b.branchName, b.province, b.deliveredParcels, b.delayedParcels, b.delayRate]),
    ];
    const csv = lines.map(row => row.map(csvCell).join(',')).join('\r\n');
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `parcel-summary_${this.from}_${this.to}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }
}

function monthLabel(month: string): string {
  const [y, m] = month.split('-').map(Number);
  return `${THAI_MONTHS[m - 1]} ${String(y + 543).slice(-2)}`;
}

function csvCell(v: string | number): string {
  const s = String(v);
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

// ปัดค่าสูงสุดของแกนให้เป็นเลขกลม (เช่น 11,816 → 12,000)
function niceMax(v: number): number {
  if (v <= 0) return 0;
  const raw = v / 4;                                   // ต้องการ ~4 ช่อง
  const mag = 10 ** Math.floor(Math.log10(raw));
  const step = ([1, 2, 2.5, 5, 10].find(s => s * mag >= raw) ?? 10) * mag;
  return Math.ceil(v / step) * step;
}

function ticks(max: number, count: number): number[] {
  return max ? Array.from({ length: count + 1 }, (_, i) => (max / count) * i) : [0];
}

// แท่งมุมบนโค้ง 4px ฐานตรง
function roundedTop(x: number, y: number, w: number, h: number, r: number): string {
  if (h <= 0) return '';
  const rr = Math.min(r, w / 2, h);
  return `M${x},${y + h} V${y + rr} Q${x},${y} ${x + rr},${y} H${x + w - rr} Q${x + w},${y} ${x + w},${y + rr} V${y + h} Z`;
}
