import json
from pathlib import Path
p=Path('package-lock.json');d=json.loads(p.read_text(encoding='utf-8-sig'));d['packages']['']['engines']={'node':'>=20'};p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
