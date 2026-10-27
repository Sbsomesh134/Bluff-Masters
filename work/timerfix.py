from pathlib import Path
p=Path('supabase/migrations/202610270003_policy_and_fixes.sql');s=p.read_text(encoding='utf-8-sig')
s=s.replace("v_room.deadline_at<=now()", "v_room.deadline_at<=clock_timestamp()")
s=s.replace("deadline_at=now()+interval '60 seconds'", "deadline_at=clock_timestamp()+interval '60 seconds'")
s=s.replace("if v_room.status<>'active' or v_room.phase<>'submit' then raise exception 'Submissions are closed.'; end if;\n  v_answer", "if v_room.status<>'active' or v_room.phase<>'submit' then raise exception 'Submissions are closed.'; end if;\n  if v_room.deadline_at<=clock_timestamp() then perform public.resolve_deadline(v_code); return public.build_game_state(v_code,p_user); end if;\n  v_answer")
s=s.replace("if v_room.status<>'active' or v_room.phase<>'vote' then raise exception 'Voting is closed.'; end if;\n  v_target", "if v_room.status<>'active' or v_room.phase<>'vote' then raise exception 'Voting is closed.'; end if;\n  if v_room.deadline_at<=clock_timestamp() then perform public.resolve_deadline(v_code); return public.build_game_state(v_code,p_user); end if;\n  v_target")
p.write_text(s,encoding='utf-8')
p=Path('supabase/migrations/202610270001_init.sql');s=p.read_text(encoding='utf-8-sig').replace("r.deadline_at>now()", "r.deadline_at>clock_timestamp()");p.write_text(s,encoding='utf-8')
p=Path('supabase/migrations/202610270005_randomized_truth.sql');s=p.read_text(encoding='utf-8-sig').replace("deadline_at=now()+interval '30 seconds'", "deadline_at=clock_timestamp()+interval '30 seconds'");p.write_text(s,encoding='utf-8')
