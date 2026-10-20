-- ศูนย์รวมงานครู (Teacher Dashboard) : ตั้งค่าฐานข้อมูล Supabase
-- วิธีใช้: Supabase > โปรเจกต์ timetable-ftt > SQL Editor > New query > วางทั้งไฟล์ > Run
-- ไฟล์นี้สร้างตารางใหม่ 2 ตาราง และฟังก์ชัน 3 ตัว ไม่แตะตารางเดิมของโปรเจกต์
-- รหัสผ่านเริ่มต้นสำหรับเข้าโหมดครู: piw-936793  (เปลี่ยนได้ในหน้าเว็บ เมนู "เปลี่ยนรหัสผ่าน")

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.hub_pages (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.hub_pages enable row level security;
drop policy if exists "hub pages are public to read" on public.hub_pages;
create policy "hub pages are public to read" on public.hub_pages
  for select to anon, authenticated using (true);
-- ไม่มีสิทธิ์เขียนตรง ๆ: การบันทึกต้องผ่านฟังก์ชัน hub_save ที่ตรวจรหัสผ่านเท่านั้น

create table if not exists public.hub_secrets (
  id text primary key references public.hub_pages(id) on delete cascade,
  pin_hash text not null,
  failed int not null default 0,
  locked_until timestamptz
);
alter table public.hub_secrets enable row level security;
-- ไม่มี policy: ไม่มีใครอ่านตารางนี้ได้ นอกจากฟังก์ชันด้านล่าง

-- ตรวจรหัสผ่าน: ผิด 5 ครั้งติดกัน ล็อก 15 นาที
create or replace function public.hub_check_pin(p_id text, p_pin text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare s public.hub_secrets;
begin
  select * into s from public.hub_secrets where id = p_id for update;
  if not found then return false; end if;
  if s.locked_until is not null and s.locked_until > now() then
    raise exception 'locked';
  end if;
  if s.pin_hash = crypt(coalesce(p_pin,''), s.pin_hash) then
    update public.hub_secrets set failed = 0, locked_until = null where id = p_id;
    return true;
  end if;
  update public.hub_secrets
     set failed = s.failed + 1,
         locked_until = case when s.failed + 1 >= 5 then now() + interval '15 minutes' else null end
   where id = p_id;
  perform pg_sleep(0.6);
  return false;
end $$;

-- บันทึกข้อมูลหน้าเว็บ (คืนค่า null ถ้ารหัสผ่านผิด)
create or replace function public.hub_save(p_id text, p_pin text, p_data jsonb, p_base timestamptz)
returns timestamptz language plpgsql security definer set search_path = public, extensions as $$
declare cur timestamptz; ts timestamptz;
begin
  if not public.hub_check_pin(p_id, p_pin) then return null; end if;
  select updated_at into cur from public.hub_pages where id = p_id for update;
  if p_base is not null and cur is not null and cur > p_base + interval '1 millisecond' then
    raise exception 'conflict';
  end if;
  if pg_column_size(p_data) > 3000000 then raise exception 'too_large'; end if;
  update public.hub_pages set data = p_data, updated_at = now() where id = p_id
  returning updated_at into ts;
  return ts;
end $$;

-- เปลี่ยนรหัสผ่าน (คืนค่า false ถ้ารหัสเดิมผิด)
create or replace function public.hub_change_pin(p_id text, p_old text, p_new text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
begin
  if length(coalesce(p_new,'')) < 6 then raise exception 'short_pin'; end if;
  if not public.hub_check_pin(p_id, p_old) then return false; end if;
  update public.hub_secrets set pin_hash = crypt(p_new, gen_salt('bf')) where id = p_id;
  return true;
end $$;

revoke all on function public.hub_check_pin(text,text) from public;
revoke all on function public.hub_save(text,text,jsonb,timestamptz) from public;
revoke all on function public.hub_change_pin(text,text,text) from public;
grant execute on function public.hub_check_pin(text,text) to anon, authenticated;
grant execute on function public.hub_save(text,text,jsonb,timestamptz) to anon, authenticated;
grant execute on function public.hub_change_pin(text,text,text) to anon, authenticated;

-- ข้อมูลเริ่มต้น (ถ้ามีข้อมูลอยู่แล้ว จะไม่เขียนทับ)
insert into public.hub_pages (id, data) values ('main', $hub${"title":"Teacher Dashboard","tagline":"Teach · Inspire · Grow","name":"ครูปรัชญา ทรงบรรพต","school":"ครูภาษาอังกฤษ","schoolShort":"โรงเรียนวรราชาทินัดดามาตุวิทยา","quote":"ทุกวันคือโอกาสในการสร้างการเปลี่ยนแปลง","tags":["English Teacher","ม.3 · ม.4 · ม.5","Classroom Tool Maker"],"avatar":"profile.jpeg","groups":[{"id":"g1","name":"คะแนนและวัดผล","ico":"gradebook","c":340},{"id":"g2","name":"ตารางสอน","ico":"timetable","c":210},{"id":"g3","name":"งานฝ่ายและกลุ่มสาระ","ico":"meeting","c":42},{"id":"g4","name":"PA และวิทยฐานะ","ico":"medal","c":265},{"id":"g5","name":"บทเรียนและเกมในห้อง","ico":"game","c":140}],"links":[{"id":"l1","g":"g1","name":"Smart Scorebook","url":"","desc":"สมุดคะแนน งานค้าง เช็กชื่อ และจิตพิสัย","ico":"gradebook","c":22},{"id":"l2","g":"g1","name":"สมุดคะแนนอิเล็กทรอนิกส์","url":"","desc":"React + Supabase มีพอร์ทัลนักเรียน","ico":"report","c":210},{"id":"l3","g":"g1","name":"SGS Auto Fill","url":"https://claude.ai/artifact/WrX7Y3nnBnVPXLVUdsvbSY","desc":"ช่วยกรอกคะแนนเข้าระบบ SGS","ico":"form","c":172},{"id":"l4","g":"g2","name":"ค้นหาตารางสอน 2/2569","url":"https://claude.ai/artifact/UVdRMK5kdGRta8N6fjLqnp","desc":"ค้นตามครู ชั้นเรียน หรือห้อง","ico":"tsearch","c":210},{"id":"l5","g":"g2","name":"ตารางสอน วรราชาทินัดดามาตุ","url":"https://claude.ai/artifact/Cs4ucDHoRp8NTPqoipUm2J","desc":"ตารางสอนรวมของโรงเรียน","ico":"timetable","c":340},{"id":"l6","g":"g2","name":"ตารางติวโอเน็ต ม.3","url":"https://claude.ai/artifact/7uaaYBq3MBd2Q2ZxWmwDL2","desc":"ตารางติว O-NET ชั้น ม.3","ico":"schedule","c":22},{"id":"l7","g":"g3","name":"WNM งานวัดผลและประเมินผล Ver.25","url":"https://claude.ai/artifact/1BjSL5guxqBCq1ZnfhbR2F","desc":"ระบบงานฝ่ายวัดผล","ico":"assess","c":172},{"id":"l8","g":"g3","name":"WNM หลักฐานการศึกษา","url":"https://claude.ai/artifact/PmkrJrDJbC2C8ceHusAUsw","desc":"เอกสารหลักฐานการศึกษา","ico":"folder","c":42},{"id":"l9","g":"g3","name":"ตารางสอนกลุ่มสาระต่างประเทศ","url":"https://claude.ai/artifact/12usE1mUR1BYumPnQnxuW6","desc":"ตารางครูทั้งกลุ่มสาระ","ico":"meeting","c":265},{"id":"l10","g":"g4","name":"วิเคราะห์ชุดแผนการสอน Green Hero","url":"https://claude.ai/artifact/4fkfphFgr8rvjtiSsL21PH","desc":"ตามเกณฑ์ PA ชำนาญการพิเศษ","ico":"medal","c":340},{"id":"l11","g":"g5","name":"English Passport M.3","url":"https://claude.ai/artifact/4NPyS4uU5emXjsRDzEzmo5","desc":"กิจกรรมสะสมผลงาน ม.3","ico":"passport","c":210},{"id":"l12","g":"g5","name":"Green Hero Academy","url":"","desc":"Environment + Conditionals ม.3","ico":"globe","c":140},{"id":"l13","g":"g5","name":"Have/Has Got Spinning Wheel","url":"","desc":"เกมวงล้อคำศัพท์ ม.1","ico":"wheel","c":22},{"id":"l14","g":"g5","name":"Present Progressive Wheel","url":"","desc":"เกมวงล้อสำหรับโปรเจกเตอร์","ico":"wheel","c":340},{"id":"l15","g":"g5","name":"Museum of Words","url":"","desc":"there was / there were","ico":"museum","c":265},{"id":"l16","g":"g5","name":"Wh-Question Battle","url":"","desc":"เกมกระดาน Present Simple","ico":"chat","c":172},{"id":"l17","g":"g5","name":"Parts of Speech Quiz","url":"","desc":"แบบทดสอบพร้อมสรุปผล","ico":"quiz","c":2},{"id":"l18","g":"g5","name":"LMS พยัญชนะไทยและอักษรโรมัน","url":"","desc":"บทเรียน 20 ตอน + ข้อสอบ","ico":"abc","c":42}]}$hub$::jsonb)
on conflict (id) do nothing;

insert into public.hub_secrets (id, pin_hash) values ('main', extensions.crypt('piw-936793', extensions.gen_salt('bf')))
on conflict (id) do nothing;
