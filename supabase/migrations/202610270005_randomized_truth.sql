create or replace function public.enter_vote(p_code text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; q public.question_bank%rowtype; v_pos integer:=1; v_truth_pos integer; a record;
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
 -- Place the correct answer at a random position too; never make truth inferable from its position.
 v_truth_pos:=1+floor(random()*v_pos)::integer;
 update answer_options set position=position+1 where room_code=p_code and round_number=r.round_number and position>=v_truth_pos;
 insert into answer_options(room_code,round_number,option_id,answer_text,author_id,is_correct,position)
  values(p_code,r.round_number,'truth',q.answer,null,true,v_truth_pos);
 update rooms set phase='vote',deadline_at=clock_timestamp()+interval '30 seconds',updated_at=now() where room_code=p_code;
end $$;
revoke all on function public.enter_vote(text) from public,anon,authenticated;
grant execute on function public.enter_vote(text) to service_role;
grant all on table public.question_reports to service_role;
update public.question_bank set prompt='What was the Aztec word used for a cacao drink often prepared with spices?',answer='Xocolatl',explanation='Mesoamerican cacao drinks were often bitter and flavored with ingredients such as chile; xocolatl is the Nahuatl term associated with such drinks.' where prompt='Which popular chocolate treat was first sold as a medicine in the 19th century?';

