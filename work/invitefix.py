from pathlib import Path
p=Path('src/main.jsx');s=p.read_text(encoding='utf-8-sig')
s=s.replace("const code=new URLSearchParams(location.search).get('room')||sessionStorage.getItem('bluff-room'); if(code){setJoinCode(code);refresh(code)}", "const inviteCode=new URLSearchParams(location.search).get('room'); const savedCode=sessionStorage.getItem('bluff-room'); if(inviteCode){setJoinCode(inviteCode.toUpperCase())}else if(savedCode){setJoinCode(savedCode);refresh(savedCode)}")
p.write_text(s,encoding='utf-8')
