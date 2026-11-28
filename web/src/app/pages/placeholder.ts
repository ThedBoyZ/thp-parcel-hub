import { Component, input } from '@angular/core';
import { RouterLink } from '@angular/router';

// หน้าชั่วคราวสำหรับเมนูที่ยังพัฒนาอยู่ (heading มาจาก data ของ route)
@Component({
  selector: 'app-placeholder',
  imports: [RouterLink],
  template: `
    <div class="container page">
      <div class="breadcrumb"><a routerLink="/">หน้าแรก</a> › {{ heading() }}</div>
      <h1>{{ heading() }}</h1>
      <p class="alert alert-info">หน้านี้กำลังพัฒนา</p>
    </div>
  `,
})
export class Placeholder {
  readonly heading = input('');
}
