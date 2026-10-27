begin;
do $$
declare
 u1 uuid:=gen_random_uuid(); u2 uuid:=gen_random_uuid(); code1 text; code2 text;
 state1 jsonb; state2 jsonb; p2 text;
 s1 integer; s2 integer;
begin
 state1:=public.game_action(u1,'create',null,jsonb_build_object('name','Tester One','avatar','🦊'));
 code1:=state1->'room'->>'room_code';
 perform public.game_action(u2,'join',code1,jsonb_build_object('name','Tester Two','avatar','🐸'));
 perform public.game_action(u2,'ready',code1,jsonb_build_object('ready',true));
 perform public.game_action(u1,'start',code1,'{}'::jsonb);
 perform public.game_action(u1,'submit',code1,jsonb_build_object('answer','UNIQUE_FAKE_FROM_ONE'));
 state2:=public.game_action(u2,'submit',code1,jsonb_build_object('answer','UNIQUE_FAKE_FROM_TWO'));
 state1:=public.game_action(u1,'state',code1,'{}'::jsonb);
 if state1->'room'->>'phase'<>'vote' then raise exception 'All submissions did not open voting.'; end if;
 if state1::text like '%UNIQUE_FAKE_FROM_ONE%' then raise exception 'A player received their own fake answer as a vote choice.'; end if;
 if state1->'room' ? 'reveal' then raise exception 'Reveal data appeared before votes were complete.'; end if;
 select option_id into p2 from public.answer_options where room_code=code1 and round_number=1 and author_id=u2;
 begin
  perform public.game_action(u1,'vote',code1,jsonb_build_object('target',u1::text));
  raise exception 'TEST: self vote unexpectedly succeeded';
 exception when others then if sqlerrm='TEST: self vote unexpectedly succeeded' then raise; end if; end;
 perform public.game_action(u1,'vote',code1,jsonb_build_object('target',p2));
 perform public.game_action(u2,'vote',code1,jsonb_build_object('target','truth'));
 state1:=public.game_action(u1,'state',code1,'{}'::jsonb);
 if state1->'room'->>'phase'<>'reveal' then raise exception 'Voting completion did not reveal.'; end if;
 select score into s1 from public.players where room_code=code1 and player_id=u1;
 select score into s2 from public.players where room_code=code1 and player_id=u2;
 if s1<>0 or s2<>5 then raise exception 'Unexpected score breakdown: player one %, player two %; expected 0 and 5.',s1,s2; end if;
 if not (state1->'room'->'reveal' ? 'correct_answer') then raise exception 'Correct answer missing during reveal.'; end if;
 begin
  perform public.game_action(u1,'vote',code1,jsonb_build_object('target','truth'));
  raise exception 'TEST: duplicate vote unexpectedly succeeded';
 exception when others then if sqlerrm='TEST: duplicate vote unexpectedly succeeded' then raise; end if; end;

 -- A deadline transition is server-side and can advance only one phase.
 state2:=public.game_action(u1,'create',null,jsonb_build_object('name','Deadline Host','avatar','🦉'));
 code2:=state2->'room'->>'room_code';
 perform public.game_action(u2,'join',code2,jsonb_build_object('name','Deadline Guest','avatar','🐙'));
 perform public.game_action(u2,'ready',code2,jsonb_build_object('ready',true));
 perform public.game_action(u1,'start',code2,'{}'::jsonb);
 update public.rooms set deadline_at=now()-interval '1 second' where room_code=code2;
 state2:=public.game_action(u1,'advance',code2,'{}'::jsonb);
 if state2->'room'->>'phase'<>'vote' then raise exception 'Expired submission phase did not advance exactly once.'; end if;
 if exists(select 1 from public.submissions where room_code=code2) then raise exception 'Late submission was accepted.'; end if;
end $$;
rollback;

