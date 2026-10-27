from pathlib import Path
p=Path('package.json');p.write_text(p.read_text(encoding='utf-8-sig'),encoding='utf-8')
