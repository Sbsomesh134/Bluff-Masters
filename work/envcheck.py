from pathlib import Path
for fn in ['.env','.env.local','.env.example']:
 p=Path(fn)
 print(fn, 'exists' if p.exists() else 'missing')
 if p.exists():
  for line in p.read_text(encoding='utf-8-sig').splitlines():
   if line.startswith('VITE_SUPABASE_URL='):
    print(' VITE_SUPABASE_URL='+line.split('=',1)[1])
   elif line.startswith('VITE_SUPABASE_ANON_KEY='):
    value=line.split('=',1)[1]
    print(' VITE_SUPABASE_ANON_KEY present length='+str(len(value))+' prefix='+value[:12])
