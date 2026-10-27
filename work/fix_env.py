from pathlib import Path
import re
src=Path('.env').read_text(encoding='utf-8-sig').splitlines()
vals={}
for line in src:
 if line.strip() and not line.lstrip().startswith('#') and '=' in line:
  k,v=line.split('=',1); vals[k.strip()]=v.strip()
url=vals.get('VITE_SUPABASE_URL','').rstrip('/')
url=re.sub(r'/rest/v1$','',url)
if not url.startswith('https://') or '.supabase.co' not in url:
 raise SystemExit('Existing Supabase URL is not in the expected project URL format.')
key=vals.get('VITE_SUPABASE_ANON_KEY','')
if not key.startswith('sb_publishable_') and not key.startswith('eyJ'):
 raise SystemExit('Existing Supabase key is missing or not a publishable/anon key.')
Path('.env.local').write_text('VITE_SUPABASE_URL='+url+'\nVITE_SUPABASE_ANON_KEY='+key+'\n',encoding='utf-8')
Path('.env.example').write_text('VITE_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co\nVITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY\n',encoding='utf-8')
print('Created .env.local with corrected project base URL; publishable key copied without displaying it.')
print('Updated .env.example to use placeholders only.')
