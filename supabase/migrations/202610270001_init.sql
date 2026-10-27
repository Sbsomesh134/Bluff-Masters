create extension if not exists pgcrypto;

create table if not exists public.question_bank (
  id integer generated always as identity primary key,
  category text not null,
  difficulty text not null check (difficulty in ('EASY','MEDIUM','HARD')),
  prompt text not null,
  answer text not null,
  explanation text not null,
  active boolean not null default true
);

create table if not exists public.rooms (
  room_code text primary key check (room_code ~ '^[A-F0-9]{6}$'),
  host_id uuid not null,
  status text not null default 'lobby' check (status in ('lobby','active','finished')),
  phase text not null default 'lobby' check (phase in ('lobby','submit','vote','reveal','finished')),
  round_number integer not null default 0 check (round_number between 0 and 8),
  question_id integer references public.question_bank(id),
  deadline_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.players (
  room_code text not null references public.rooms(room_code) on delete cascade,
  player_id uuid not null,
  display_name text not null check (char_length(display_name) between 2 and 20),
  avatar text not null default '🦊',
  is_host boolean not null default false,
  ready boolean not null default false,
  score integer not null default 0 check (score >= 0),
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (room_code, player_id)
);
create unique index if not exists players_room_name_unique on public.players(room_code, lower(display_name));
create table if not exists public.room_round_questions (
  room_code text not null references public.rooms(room_code) on delete cascade,
  round_number integer not null check (round_number between 1 and 8),
  question_id integer not null references public.question_bank(id),
  primary key(room_code,round_number),
  unique(room_code,question_id)
);
create table if not exists public.submissions (
  room_code text not null,
  round_number integer not null,
  player_id uuid not null,
  answer text not null check (char_length(answer) between 2 and 120),
  created_at timestamptz not null default now(),
  primary key(room_code,round_number,player_id),
  foreign key(room_code,player_id) references public.players(room_code,player_id) on delete cascade
);
create table if not exists public.answer_options (
  room_code text not null,
  round_number integer not null,
  option_id text not null,
  answer_text text not null,
  author_id uuid,
  is_correct boolean not null default false,
  position integer not null,
  primary key(room_code,round_number,option_id)
);
create table if not exists public.votes (
  room_code text not null,
  round_number integer not null,
  voter_id uuid not null,
  target_id text not null,
  created_at timestamptz not null default now(),
  primary key(room_code,round_number,voter_id),
  foreign key(room_code,voter_id) references public.players(room_code,player_id) on delete cascade
);
create table if not exists public.round_scores (
  room_code text not null,
  round_number integer not null,
  player_id uuid not null,
  correct_points integer not null default 0,
  bluff_points integer not null default 0,
  points_total integer not null default 0,
  primary key(room_code,round_number,player_id),
  foreign key(room_code,player_id) references public.players(room_code,player_id) on delete cascade
);

create index if not exists rooms_updated_at_idx on public.rooms(updated_at);
create index if not exists players_room_idx on public.players(room_code);
create index if not exists submissions_room_round_idx on public.submissions(room_code,round_number);
create index if not exists votes_room_round_idx on public.votes(room_code,round_number);

alter table public.rooms enable row level security;
alter table public.players enable row level security;
alter table public.question_bank enable row level security;
alter table public.room_round_questions enable row level security;
alter table public.submissions enable row level security;
alter table public.answer_options enable row level security;
alter table public.votes enable row level security;
alter table public.round_scores enable row level security;

drop policy if exists "Room members can read safe room state" on public.rooms;
create policy "Room members can read safe room state" on public.rooms for select to authenticated
using (exists (select 1 from public.players p where p.room_code=rooms.room_code and p.player_id=auth.uid() and p.left_at is null));
drop policy if exists "Room members can read roster" on public.players;
create policy "Room members can read roster" on public.players for select to authenticated
using (exists (select 1 from public.players me where me.room_code=players.room_code and me.player_id=auth.uid() and me.left_at is null));
-- All writes and private game reads go through the Edge Function using the service role.
-- No client policies are defined for question_bank, round questions, submissions, options, votes or scores.
grant select on public.rooms, public.players to authenticated;
grant select on public.rooms, public.players to anon;
revoke all on public.submissions, public.answer_options, public.votes, public.round_scores, public.room_round_questions, public.question_bank from anon, authenticated;

do $$ begin
  alter publication supabase_realtime add table public.rooms;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.players;
exception when duplicate_object then null; when undefined_object then null; end $$;

create or replace function public.game_action(p_user uuid,p_action text,p_code text default null,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_code text:=upper(coalesce(p_code,''));
  v_room public.rooms%rowtype;
  v_player public.players%rowtype;
  v_question public.question_bank%rowtype;
  v_result jsonb;
  v_name text;
  v_avatar text;
  v_target text;
  v_answer text;
  v_count integer;
  v_round integer;
begin
  if p_user is null then raise exception 'Sign in as a guest to play.'; end if;
  if p_action='create' then
    v_name:=btrim(coalesce(p_payload->>'name',''));
    v_avatar:=coalesce(p_payload->>'avatar','🦊');
    if char_length(v_name)<2 or char_length(v_name)>20 then raise exception 'Choose a name between 2 and 20 characters.'; end if;
    loop
      v_code:=upper(encode(gen_random_bytes(3),'hex'));
      exit when not exists(select 1 from rooms where room_code=v_code);
    end loop;
    insert into rooms(room_code,host_id) values(v_code,p_user);
    insert into players(room_code,player_id,display_name,avatar,is_host,ready) values(v_code,p_user,v_name,v_avatar,true,true);
    return public.build_game_state(v_code,p_user);
  end if;
  if p_action='join' then
    v_code:=upper(coalesce(p_payload->>'code',p_code,''));
    if v_code !~ '^[A-F0-9]{6}$' then raise exception 'Enter a valid six-character room code.'; end if;
    select * into v_room from rooms where room_code=v_code for update;
    if not found then raise exception 'That room code was not found.'; end if;
    v_name:=btrim(coalesce(p_payload->>'name',''));
    v_avatar:=coalesce(p_payload->>'avatar','🦊');
    select * into v_player from players where room_code=v_code and player_id=p_user;
    if found then
      update players set last_seen_at=now(),left_at=null where room_code=v_code and player_id=p_user;
    else
      if v_room.status<>'lobby' then raise exception 'This game has already started. Ask the host to invite you to the next game.'; end if;
      if (select count(*) from players where room_code=v_code and left_at is null)>=8 then raise exception 'This room is full.'; end if;
      if char_length(v_name)<2 or char_length(v_name)>20 then raise exception 'Choose a name between 2 and 20 characters.'; end if;
      if exists(select 1 from players where room_code=v_code and lower(display_name)=lower(v_name) and left_at is null) then raise exception 'That name is already taken in this room.'; end if;
      insert into players(room_code,player_id,display_name,avatar) values(v_code,p_user,v_name,v_avatar);
    end if;
    return public.build_game_state(v_code,p_user);
  end if;
  if v_code !~ '^[A-F0-9]{6}$' then raise exception 'Enter a valid six-character room code.'; end if;
  select * into v_room from rooms where room_code=v_code for update;
  if not found then raise exception 'That room was not found.'; end if;
  select * into v_player from players where room_code=v_code and player_id=p_user and left_at is null for update;
  if not found then raise exception 'You are not a member of this room. Join with the room code.'; end if;
  update players set last_seen_at=now() where room_code=v_code and player_id=p_user;

  -- Resolve deadlines on the server before serving or accepting a game action.
  if v_room.status='active' and v_room.phase in ('submit','vote') and v_room.deadline_at<=now() then
    perform public.resolve_deadline(v_code);
    select * into v_room from rooms where room_code=v_code for update;
  end if;

  if p_action='state' then return public.build_game_state(v_code,p_user); end if;
  if p_action='leave' then
    if v_room.status='lobby' then
      delete from players where room_code=v_code and player_id=p_user;
    else
      update players set left_at=now() where room_code=v_code and player_id=p_user;
    end if;
    if v_room.host_id=p_user then
      select player_id into v_target from players where room_code=v_code and left_at is null order by joined_at limit 1;
      if v_target is null then delete from rooms where room_code=v_code; return jsonb_build_object('room',null); end if;
      update rooms set host_id=v_target,updated_at=now() where room_code=v_code;
      update players set is_host=(player_id=v_target) where room_code=v_code;
    end if;
    return jsonb_build_object('room',null,'message','You left the room.');
  end if;
  if p_action='ready' then
    if v_room.status<>'lobby' then raise exception 'The lobby is already closed.'; end if;
    update players set ready=coalesce((p_payload->>'ready')::boolean,false) where room_code=v_code and player_id=p_user;
  elsif p_action='start' then
    if v_room.host_id<>p_user then raise exception 'Only the host can start the game.'; end if;
    if v_room.status<>'lobby' then raise exception 'This game has already started.'; end if;
    if (select count(*) from players where room_code=v_code and left_at is null)<2 then raise exception 'At least two players are needed.'; end if;
    if exists(select 1 from players where room_code=v_code and left_at is null and not ready and not is_host) then raise exception 'Everyone must be ready before starting.'; end if;
    delete from room_round_questions where room_code=v_code;
    insert into room_round_questions(room_code,round_number,question_id)
      select v_code,row_number() over(),id from (select id from question_bank where active order by random() limit 8) q;
    if (select count(*) from room_round_questions where room_code=v_code)<8 then raise exception 'The trivia bank needs at least eight active questions.'; end if;
    select q.* into v_question from question_bank q join room_round_questions rq on rq.question_id=q.id where rq.room_code=v_code and rq.round_number=1;
    update rooms set status='active',phase='submit',round_number=1,question_id=v_question.id,deadline_at=now()+interval '60 seconds',updated_at=now() where room_code=v_code;
  elsif p_action='submit' then
    if v_room.status<>'active' or v_room.phase<>'submit' then raise exception 'Submissions are closed.'; end if;
    if v_room.deadline_at<=now() then perform public.resolve_deadline(v_code); return public.build_game_state(v_code,p_user); end if;
    v_answer:=btrim(coalesce(p_payload->>'answer',''));
    if char_length(v_answer)<2 or char_length(v_answer)>120 then raise exception 'Your bluff must be between 2 and 120 characters.'; end if;
    insert into submissions(room_code,round_number,player_id,answer) values(v_code,v_room.round_number,p_user,v_answer);
    select count(*) into v_count from players where room_code=v_code and left_at is null;
    if (select count(*) from submissions where room_code=v_code and round_number=v_room.round_number)>=v_count then perform public.enter_vote(v_code); end if;
  elsif p_action='vote' then
    if v_room.status<>'active' or v_room.phase<>'vote' then raise exception 'Voting is closed.'; end if;
    if v_room.deadline_at<=now() then perform public.resolve_deadline(v_code); return public.build_game_state(v_code,p_user); end if;
    v_target:=coalesce(p_payload->>'target','');
    if not exists(select 1 from answer_options where room_code=v_code and round_number=v_room.round_number and option_id=v_target) then raise exception 'That answer is not available.'; end if;
    if exists(select 1 from answer_options where room_code=v_code and round_number=v_room.round_number and option_id=v_target and author_id=p_user) then raise exception 'You cannot vote for your own bluff.'; end if;
    insert into votes(room_code,round_number,voter_id,target_id) values(v_code,v_room.round_number,p_user,v_target);
    select count(*) into v_count from players where room_code=v_code and left_at is null;
    if (select count(*) from votes where room_code=v_code and round_number=v_room.round_number)>=v_count then perform public.score_round(v_code); end if;
  elsif p_action='advance' then
    if v_room.host_id<>p_user then
      if v_room.deadline_at>now() then raise exception 'Only the host may advance early.'; end if;
    end if;
    if v_room.phase='submit' then perform public.enter_vote(v_code);
    elsif v_room.phase='vote' then perform public.score_round(v_code);
    else raise exception 'There is no timed phase to advance.'; end if;
  elsif p_action='next' then
    if v_room.host_id<>p_user then raise exception 'Only the host may advance to the next round.'; end if;
    if v_room.phase<>'reveal' then raise exception 'Finish the reveal before advancing.'; end if;
    if v_room.round_number>=8 then
      update rooms set phase='finished',status='finished',deadline_at=null,updated_at=now() where room_code=v_code;
    else
      v_round:=v_room.round_number+1;
      select q.* into v_question from question_bank q join room_round_questions rq on rq.question_id=q.id where rq.room_code=v_code and rq.round_number=v_round;
      update rooms set phase='submit',round_number=v_round,question_id=v_question.id,deadline_at=now()+interval '60 seconds',updated_at=now() where room_code=v_code;
    end if;
  elsif p_action='rematch' then
    if v_room.host_id<>p_user then raise exception 'Only the host can start a rematch.'; end if;
    if v_room.status<>'finished' then raise exception 'Finish the match before starting a rematch.'; end if;
    delete from submissions where room_code=v_code;
    delete from answer_options where room_code=v_code;
    delete from votes where room_code=v_code;
    delete from round_scores where room_code=v_code;
    delete from room_round_questions where room_code=v_code;
    insert into room_round_questions(room_code,round_number,question_id)
      select v_code,row_number() over(),id from (select id from question_bank where active order by random() limit 8) q;
    update players set score=0,ready=(player_id=p_user),left_at=null,last_seen_at=now() where room_code=v_code;
    update rooms set status='lobby',phase='lobby',round_number=0,question_id=null,deadline_at=null,updated_at=now() where room_code=v_code;
    update rooms set host_id=p_user where room_code=v_code;
    update players set is_host=(player_id=p_user) where room_code=v_code;
  else
    raise exception 'Unknown game action.';
  end if;
  update rooms set updated_at=now() where room_code=v_code;
  return public.build_game_state(v_code,p_user);
end $$;

create or replace function public.enter_vote(p_code text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; q public.question_bank%rowtype; v_pos integer:=1; a record;
begin
  select * into r from rooms where room_code=p_code for update;
  if r.phase<>'submit' then return; end if;
  select * into q from question_bank where id=r.question_id;
  delete from answer_options where room_code=p_code and round_number=r.round_number;
  for a in select player_id,answer from submissions where room_code=p_code and round_number=r.round_number order by random() loop
    insert into answer_options(room_code,round_number,option_id,answer_text,author_id,is_correct,position)
      values(p_code,r.round_number,a.player_id::text,a.answer,a.player_id,false,v_pos);
    v_pos:=v_pos+1;
  end loop;
  insert into answer_options(room_code,round_number,option_id,answer_text,author_id,is_correct,position)
    values(p_code,r.round_number,'truth',q.answer,null,true,v_pos);
  update rooms set phase='vote',deadline_at=now()+interval '30 seconds',updated_at=now() where room_code=p_code;
end $$;

create or replace function public.score_round(p_code text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; n integer;
begin
  select * into r from rooms where room_code=p_code for update;
  if r.phase<>'vote' then return; end if;
  insert into round_scores(room_code,round_number,player_id,correct_points,bluff_points,points_total)
  select p_code,r.round_number,p.player_id,
    case when exists(select 1 from votes v where v.room_code=p_code and v.round_number=r.round_number and v.voter_id=p.player_id and v.target_id='truth') then 3 else 0 end,
    coalesce((select count(*)*2 from votes v join answer_options o on o.room_code=v.room_code and o.round_number=v.round_number and o.option_id=v.target_id where v.room_code=p_code and v.round_number=r.round_number and o.author_id=p.player_id and v.voter_id<>p.player_id),0)::integer,
    (case when exists(select 1 from votes v where v.room_code=p_code and v.round_number=r.round_number and v.voter_id=p.player_id and v.target_id='truth') then 3 else 0 end)+
    coalesce((select count(*)*2 from votes v join answer_options o on o.room_code=v.room_code and o.round_number=v.round_number and o.option_id=v.target_id where v.room_code=p_code and v.round_number=r.round_number and o.author_id=p.player_id and v.voter_id<>p.player_id),0)::integer
  from players p where p.room_code=p_code and p.left_at is null;
  update players p set score=p.score+s.points_total from round_scores s where s.room_code=p_code and s.round_number=r.round_number and s.player_id=p.player_id;
  update rooms set phase='reveal',deadline_at=null,updated_at=now() where room_code=p_code;
end $$;

create or replace function public.resolve_deadline(p_code text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; n integer;
begin
 select * into r from rooms where room_code=p_code for update;
 if r.deadline_at is null or r.deadline_at>clock_timestamp() then return; end if;
 if r.phase='submit' then perform public.enter_vote(p_code);
 elsif r.phase='vote' then perform public.score_round(p_code);
 end if;
end $$;

create or replace function public.build_game_state(p_code text,p_user uuid) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; q public.question_bank%rowtype; out_room jsonb; opts jsonb; ballots jsonb; board jsonb; me jsonb;
begin
 select * into r from rooms where room_code=p_code;
 if not found then return jsonb_build_object('room',null); end if;
 select to_jsonb(p) into me from players p where p.room_code=p_code and p.player_id=p_user;
 select jsonb_agg(jsonb_build_object('id',p.player_id,'name',p.display_name,'avatar',p.avatar,'is_host',p.is_host,'ready',p.ready,'score',p.score,'connected',(p.last_seen_at>now()-interval '45 seconds' and p.left_at is null),'has_submitted',exists(select 1 from submissions s where s.room_code=p_code and s.round_number=r.round_number and s.player_id=p.player_id),'has_voted',exists(select 1 from votes v where v.room_code=p_code and v.round_number=r.round_number and v.voter_id=p.player_id),'round_points',coalesce((select points_total from round_scores rs where rs.room_code=p_code and rs.round_number=r.round_number and rs.player_id=p.player_id),0)) order by p.score desc,p.joined_at)
 into board from players p where p.room_code=p_code and p.left_at is null;
 if r.question_id is not null then select * into q from question_bank where id=r.question_id; end if;
 opts:='[]'::jsonb;
 if r.phase='vote' then
   select coalesce(jsonb_agg(jsonb_build_object('id',o.option_id,'text',o.answer_text) order by o.position),'[]'::jsonb) into opts
   from answer_options o where o.room_code=p_code and o.round_number=r.round_number and (o.author_id is null or o.author_id<>p_user);
 end if;
 ballots:='[]'::jsonb;
 if r.phase in ('reveal','finished') then
   select coalesce(jsonb_agg(jsonb_build_object('id',o.option_id,'text',o.answer_text,'is_correct',o.is_correct,'author_name',author.display_name,'voters',coalesce(vs.people,'[]'::jsonb)) order by o.position),'[]'::jsonb)
   into ballots from answer_options o left join players author on author.room_code=p_code and author.player_id=o.author_id
   left join lateral (select jsonb_agg(jsonb_build_object('id',voter.player_id,'name',voter.display_name)) people from votes v join players voter on voter.room_code=v.room_code and voter.player_id=v.voter_id where v.room_code=o.room_code and v.round_number=o.round_number and v.target_id=o.option_id) vs on true
   where o.room_code=p_code and o.round_number=r.round_number;
 end if;
 out_room:=jsonb_build_object('room_code',r.room_code,'status',r.status,'phase',r.phase,'round_number',r.round_number,'rounds_total',8,'host_id',r.host_id,'deadline_at',r.deadline_at,'players',coalesce(board,'[]'::jsonb),'player',me);
 if r.question_id is not null then out_room:=out_room||jsonb_build_object('question',jsonb_build_object('prompt',q.prompt,'category',q.category,'difficulty',q.difficulty)); end if;
 if r.phase='vote' then out_room:=out_room||jsonb_build_object('choices',opts); end if;
 if r.phase in ('reveal','finished') then out_room:=out_room||jsonb_build_object('reveal',jsonb_build_object('correct_answer',q.answer,'explanation',q.explanation,'answers',ballots,'scoreboard',coalesce(board,'[]'::jsonb))); end if;
 if exists(select 1 from submissions where room_code=p_code and round_number=r.round_number and player_id=p_user) then out_room:=out_room||jsonb_build_object('my_submission',true); end if;
 if exists(select 1 from votes where room_code=p_code and round_number=r.round_number and voter_id=p_user) then out_room:=out_room||jsonb_build_object('my_vote',true); end if;
 return jsonb_build_object('room',out_room);
end $$;

revoke all on function public.game_action(uuid,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.build_game_state(text,uuid) from public,anon,authenticated;
revoke all on function public.enter_vote(text),public.score_round(text),public.resolve_deadline(text) from public,anon,authenticated;
grant execute on function public.game_action(uuid,text,text,jsonb) to service_role;

