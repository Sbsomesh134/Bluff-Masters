from pathlib import Path
Path('supabase/diagnostics').mkdir(exist_ok=True)
Path('supabase/diagnostics/gen_random_bytes.sql').write_text(Path('work/diag_source.tmp').read_text(encoding='utf-8-sig'),encoding='utf-8')
Path('supabase/migrations/202610271200_fix_gen_random_bytes_search_path.sql').write_text(Path('work/migration_source.tmp').read_text(encoding='utf-8-sig'),encoding='utf-8')
