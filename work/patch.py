from pathlib import Path
p=Path('src/main.jsx')
s=p.read_text(encoding='utf-8-sig')
s=s.replace("<span className={'ready-state '+(p.ready?'ready':'waiting')}>{p.ready?<Check size={14}/>:<span/>}</span></div>", "{host&&p.id!==me?.id&&<button className=\"kick-btn\" aria-label={'Remove '+p.name} onClick={()=>act('kick',{player_id:p.id})}>×</button>}<span className={'ready-state '+(p.ready?'ready':'waiting')}>{p.ready?<Check size={14}/>:<span/>}</span></div>")
s=s.replace('<div className="reveal-bottom"><div><span className="muted">ROUND {room.round_number} COMPLETE</span>', '<div className="reveal-bottom"><button className="report-btn" onClick={()=>act(\'report\')}>Report a questionable fact</button><div><span className="muted">ROUND {room.round_number} COMPLETE</span>')
p.write_text(s,encoding='utf-8')
