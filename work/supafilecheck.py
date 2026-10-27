from pathlib import Path
for p in [Path(r'C:/Users/anjal/.supabase/access-token'),Path(r'C:/Users/anjal/.supabase/profile'),Path(r'C:/Users/anjal/.supabase/config.json')]: print(p.name, 'present' if p.exists() else 'absent')
