# Teacher Dashboard · ศูนย์รวมงานครูปรัชญา

หน้าเว็บรวมลิงก์ระบบทั้งหมดของครู เปิดได้ทุกเครื่องโดยไม่ต้องล็อกอิน

- ลิงก์หน้าเว็บ: https://pratchayapiw.github.io/teacherpratchaya-piw/
- ข้อมูลหน้าเว็บเก็บใน Supabase (โปรเจกต์ timetable-ftt ตาราง `hub_pages`)
- ครูแก้ไขได้ที่เมนู "โหมดครู (แก้ไข)" ด้วยรหัสผ่าน คนอื่นดูได้อย่างเดียว

## ไฟล์ใน repo
- `index.html` หน้าเว็บทั้งหมด (หน้าตา ไอคอน และข้อมูลสำรอง)
- `profile.jpeg` รูปโปรไฟล์ครู

## ตั้งค่าครั้งแรก
1. Supabase > timetable-ftt > SQL Editor > วางไฟล์ `hub-setup.sql` > Run (ทำครั้งเดียว)
2. GitHub > Settings > Pages > Branch: `main` / `(root)` > Save
