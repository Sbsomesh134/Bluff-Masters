from pathlib import Path
import re
p=Path('.env'); lines=p.read_text(encoding='utf-8-sig').splitlines(); out=[]
for line in lines:
 if line.startswith('VITE_SUPABASE_URL='):
  u=line.split('=',1)[1].rstrip('/'); u=re.sub(r'/rest/v1$','',u); line='VITE_SUPABASE_URL='+u
 out.append(line)
p.write_text('\n'.join(out)+'\n',encoding='utf-8')
print('Corrected VITE_SUPABASE_URL in .env; key value was left unchanged.')
