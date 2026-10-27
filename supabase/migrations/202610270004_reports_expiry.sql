create table if not exists public.question_reports (
  room_code text not null references public.rooms(room_code) on delete cascade,
  round_number integer not null,
  question_id integer not null references public.question_bank(id),
  player_id uuid not null,
  details text not null default '' check (char_length(details)<=300),
  created_at timestamptz not null default now(),
  primary key(room_code,round_number,player_id),
  foreign key(room_code,player_id) references public.players(room_code,player_id) on delete cascade
);
alter table public.question_reports enable row level security;
revoke all on public.question_reports from anon,authenticated;
do $$ begin
  alter table public.answer_options add constraint answer_options_room_fk foreign key(room_code) references public.rooms(room_code) on delete cascade;
exception when duplicate_object then null; end $$;
DROP INDEX IF EXISTS public.players_room_name_unique;
CREATE UNIQUE INDEX players_room_name_unique ON public.players(room_code,lower(display_name)) WHERE left_at IS NULL;
