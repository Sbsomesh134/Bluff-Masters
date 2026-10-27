from pathlib import Path
s=Path('supabase/migrations/202610270003_policy_and_fixes.sql').read_text(encoding='utf-8-sig')
for line in s.splitlines():
 if 'v_avatar:=coalesce' in line: print(repr(line))
