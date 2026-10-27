from pathlib import Path
p=Path('src/main.jsx');s=p.read_text(encoding='utf-8-sig')
s=s.replace('<div className="winner-footer"><div><Medal size={18}/>', '<div className="final-standings">{players.slice(3).map((p,i)=><div key={p.id}><span>{String(i+4).padStart(2,\'0\')}</span><Avatar p={current(p.id)} small/><strong>{p.name}</strong><b>{p.score}</b></div>)}</div><div className="winner-footer"><div><Medal size={18}/>')
p.write_text(s,encoding='utf-8')
