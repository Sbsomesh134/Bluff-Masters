from pathlib import Path
p=Path('supabase/migrations/202610270003_policy_and_fixes.sql');s=p.read_text(encoding='utf-8-sig')
s=s.replace("select * into v_room from rooms where room_code=v_code for update; if not found then raise exception 'That room was not found.'; end if;\n select * into v_player", "select * into v_room from rooms where room_code=v_code for update; if not found then raise exception 'That room was not found.'; end if;\n if v_room.updated_at<now()-interval '24 hours' then raise exception 'This room has expired. Start a new room.'; end if;\n select * into v_player")
s=s.replace("update players set last_seen_at=now() where room_code=v_code and player_id=p_user;\n if v_room.status='active'", "if p_action<>'state' and v_player.last_seen_at<now()-interval '15 seconds' then update players set last_seen_at=now() where room_code=v_code and player_id=p_user; end if;\n if v_room.status='active'")
s=s.replace("(p.last_seen_at>now()-interval '45 seconds' and p.left_at is null)","(p.last_seen_at>now()-interval '5 minutes' and p.left_at is null)")
p.write_text(s,encoding='utf-8')
