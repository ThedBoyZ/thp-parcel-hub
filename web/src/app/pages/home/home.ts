import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { ParcelDetail, ParcelEvent } from '../../core/models';
import { STATUS_STEPS, errorMessage, statusIndex, statusLabel } from '../../core/status';

const MAX_NUMBERS = 10;

// เลขตัวอย่างครบ 5 สถานะ (สร้างไว้ใน data-generator)
const DEMO_NUMBERS = [
  { no: 'EX987654321TH', hint: 'รับฝาก' },
  { no: 'EX555000111TH', hint: 'คัดแยก' },
  { no: 'EX123456789TH', hint: 'ระหว่างขนส่ง' },
  { no: 'EX246813579TH', hint: 'ถึงปลายทาง' },
  { no: 'EX112233445TH', hint: 'นำจ่าย · ตรงเวลา' },
  { no: 'EX998877665TH', hint: 'นำจ่าย · ล่าช้า' },
];

interface Timeline {
  loading: boolean;
  events: ParcelEvent[];
  error?: string;
}

@Component({
  selector: 'app-home',
  imports: [FormsModule, RouterLink, DatePipe, DecimalPipe],
  templateUrl: './home.html',
  styleUrl: './home.css',
})
export class Home {
  private readonly api = inject(ApiService);

  protected readonly steps = STATUS_STEPS;
  protected readonly demoNumbers = DEMO_NUMBERS;
  protected readonly statusLabel = statusLabel;
  protected readonly statusIndex = statusIndex;

  protected query = '';
  protected readonly loading = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly found = signal<ParcelDetail[]>([]);
  protected readonly notFound = signal<string[]>([]);
  protected readonly searched = signal(false);
  protected readonly timelines = signal<Record<string, Timeline>>({});

  // รับเลขคั่นด้วย comma / เว้นวรรค / ขึ้นบรรทัดใหม่ → ตัวพิมพ์ใหญ่ ไม่ซ้ำ
  private parse(text: string): string[] {
    return [...new Set(text.split(/[\s,]+/).map(s => s.trim().toUpperCase()).filter(Boolean))];
  }

  protected search(): void {
    const numbers = this.parse(this.query);
    if (numbers.length === 0) {
      this.error.set('กรุณากรอกหมายเลขพัสดุ');
      return;
    }
    if (numbers.length > MAX_NUMBERS) {
      this.error.set(`ค้นหาได้ครั้งละไม่เกิน ${MAX_NUMBERS} หมายเลข`);
      return;
    }

    this.loading.set(true);
    this.error.set(null);
    this.api.searchParcels(numbers).subscribe({
      next: res => {
        this.found.set(res.found);
        this.notFound.set(res.notFound);
        this.timelines.set({});
        this.searched.set(true);
        this.loading.set(false);
        // ค้นเลขเดียว → เปิดไทม์ไลน์ให้ทันที
        if (res.found.length === 1) this.toggleTimeline(res.found[0].trackingNo);
      },
      error: err => {
        this.error.set(errorMessage(err));
        this.loading.set(false);
      },
    });
  }

  protected useDemo(no: string): void {
    this.query = no;
    this.search();
  }

  protected useAllDemos(): void {
    this.query = DEMO_NUMBERS.map(d => d.no).join(', ');
    this.search();
  }

  // โหลดไทม์ไลน์เมื่อกดเปิดครั้งแรกเท่านั้น (ครั้งต่อไปใช้ข้อมูลเดิม)
  protected toggleTimeline(no: string): void {
    const current = this.timelines();
    if (current[no]) {
      const { [no]: _, ...rest } = current;
      this.timelines.set(rest);
      return;
    }

    this.timelines.update(t => ({ ...t, [no]: { loading: true, events: [] } }));
    this.api.parcelEvents(no).subscribe({
      next: events => this.timelines.update(t => ({ ...t, [no]: { loading: false, events } })),
      error: err => this.timelines.update(t => ({
        ...t, [no]: { loading: false, events: [], error: errorMessage(err) },
      })),
    });
  }

  protected deliveryBadge(p: ParcelDetail): { text: string; css: string } {
    if (p.isDelayed === true) return { text: 'นำจ่ายล่าช้า', css: 'badge-high' };
    if (p.isDelayed === false) return { text: 'นำจ่ายตรงเวลา', css: 'badge-low' };
    return { text: statusLabel(p.currentStatus), css: 'badge-neutral' };
  }
}
