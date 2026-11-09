# Teacher Pratchaya – Email/Password Auth Kit

แพ็กเกจนี้เตรียมโค้ดสำหรับเปลี่ยน Teacher Dashboard จาก PIN เป็น Supabase Auth Email/Password โดยใช้ Supabase Project เดิม `timetable-ftt`.

## ไฟล์ในแพ็กเกจ
- `supabase-config.js` — Project URL และ Publishable Key สำหรับฝั่ง browser
- `auth.js` — เข้าสู่ระบบ, session, ตรวจสิทธิ์ admin, logout, reset password และเปลี่ยนรหัสผ่าน
- `supabase-auth-migration.sql` — สร้าง allow-list ผู้ดูแลและ RLS โดยรักษาข้อมูล `hub_pages` เดิม
- `index-integration-snippets.md` — โค้ดที่ต้องนำไปแทน/เพิ่มใน `index.html`

## ขั้นตอนที่ต้องทำตามลำดับ
1. สำรอง `index.html` และข้อมูลเดิมใน `hub_pages`.
2. ใน Supabase project `timetable-ftt` ตรวจว่า `pratchaya.piw@gmail.com` อยู่ใน Authentication → Users แล้วหรือยัง ถ้ายังไม่มี ให้สร้าง Auth user ในโปรเจกต์นี้ก่อน
3. รัน `supabase-auth-migration.sql` ใน SQL Editor ของ `timetable-ftt` เท่านั้น
4. ตรวจ query ท้ายไฟล์ SQL ต้องแสดงหนึ่งแถวของ `pratchaya.piw@gmail.com`.
5. เพิ่ม Redirect URL ใน Authentication → URL Configuration:
   `https://pratchayapiw.github.io/TeacherPratchaya-Piw/`
6. ตั้ง SMTP provider ใน Authentication → SMTP Settings เพื่อให้ส่ง reset email ได้จริงใน production.
7. อัปโหลด `supabase-config.js` และ `auth.js` ไปที่ root ของ GitHub repository.
8. แก้ `index.html` ตาม `index-integration-snippets.md`.
9. ทดสอบ login, save, logout, reset email และตั้งรหัสผ่านใหม่ ก่อนถือว่าเสร็จสมบูรณ์.

## ความปลอดภัย
- Publishable/anon key ใช้ใน browser ได้ตามปกติ แต่ห้ามใส่ `service_role`, database password หรือ SMTP secret ในไฟล์เว็บ
- Dashboard content ยังคงอ่านได้สาธารณะเหมือนเดิม แต่การแก้ไขจำกัดเฉพาะ Auth user ที่อยู่ใน `hub_admins`
- SQL ไม่ลบ `hub_pages.data` และไม่ลบตาราง PIN เก่า เพื่อให้ย้อนกลับได้ในช่วงทดสอบ
- บัญชีที่อยู่ใน Supabase Project `verifyEvaluation` ไม่ได้เป็นบัญชีใน `timetable-ftt` โดยอัตโนมัติ ต้องตรวจ/สร้างใน project `timetable-ftt` แยกต่างหาก
