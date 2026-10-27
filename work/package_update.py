from pathlib import Path
import json
p=Path('package.json');data=json.loads(p.read_text(encoding='utf-8-sig'));data['engines']={'node':'>=20'};p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
