-- 능력치 보드 데모 스키마
-- 데모 단계라 로그인 없이 누구나 조회·기록할 수 있어요(anon).
-- 실제 운영 전에는 Supabase Auth를 붙이고 아래 정책을 사용자별로 좁혀야 해요.

create table if not exists public.personnel (
  id          int primary key,
  name        text not null,
  rank        text not null,                 -- 계급 → 계층(병사/간부) 판단
  unit        text not null,
  specialty   text not null,                 -- 특기 (고정): admin | maint | signal | infantry
  job         text not null check (job in ('admin','spec','cmd')),          -- 담당 직무 (특기와 별도)
  default_job text not null check (default_job in ('admin','spec','cmd')),  -- 초기화 시 되돌릴 직무
  base_job    text not null check (base_job in ('admin','spec','cmd')),     -- 특기 기준 계열 (도입 전 XP 배분용)
  legacy_xp   int  not null default 0,       -- 시스템 도입 전 누적 XP
  stat_bonus  jsonb not null default '{}'::jsonb
);

create table if not exists public.activities (
  id           bigint generated always as identity primary key,
  personnel_id int not null references public.personnel(id) on delete cascade,
  type         text not null,                -- 활동 유형 템플릿 id
  scale        text not null check (scale in ('daily','normal','important','major')),
  role         text not null check (role in ('lead','part','sup')),
  points       numeric not null check (points > 0 and points <= 30),
  occurred_at  date not null default current_date,
  is_seed      boolean not null default false,
  created_at   timestamptz not null default now()
);
create index if not exists activities_personnel_idx on public.activities (personnel_id);

alter table public.personnel  enable row level security;
alter table public.activities enable row level security;

-- 조회: 누구나
create policy "demo read personnel"  on public.personnel  for select to anon, authenticated using (true);
create policy "demo read activities" on public.activities for select to anon, authenticated using (true);
-- 활동 기록: 누구나 추가 (시드로 위장 불가)
create policy "demo insert activities" on public.activities for insert to anon, authenticated with check (is_seed = false);
-- 초기화: 직접 기록한 활동만 삭제 가능
create policy "demo delete own activities" on public.activities for delete to anon, authenticated using (is_seed = false);
-- 담당 직무 변경: job 컬럼만 수정 가능
create policy "demo update job" on public.personnel for update to anon, authenticated using (true) with check (true);

revoke insert, update, delete on public.personnel from anon, authenticated;
grant update (job) on public.personnel to anon, authenticated;
revoke update on public.activities from anon, authenticated;
