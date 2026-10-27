import { createClient } from '@supabase/supabase-js';

const url = 'https://vvmsexdariwqshulktxt.supabase.co';
const anonKey = 'sb_publishable_9TvXMuE8HHanb0wT3CK0eA_UnXXm3ow';

async function run() {
  console.log('Testing live Supabase connection...');
  const client1 = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const client2 = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });

  console.log('1. Signing in Host anonymously...');
  const { data: auth1, error: authErr1 } = await client1.auth.signInAnonymously();
  if (authErr1) throw new Error(`Host sign-in failed: ${authErr1.message}`);
  const user1 = auth1.user;
  console.log(`   Host signed in. UID: ${user1.id}`);

  console.log('2. Invoking game-action (create room)...');
  const { data: createData, error: createErr } = await client1.functions.invoke('game-action', {
    body: { action: 'create', name: 'Sherlock', avatar: '🦊' }
  });
  if (createErr) throw new Error(`Create room error: ${JSON.stringify(createErr)} Data: ${JSON.stringify(createData)}`);
  if (createData?.error) throw new Error(`Create room API error: ${createData.error}`);
  console.log('   Create room response:', JSON.stringify(createData, null, 2));

  const room = createData?.room;
  if (!room || !room.room_code) throw new Error('No room or room_code in response');
  if (!/^[A-F0-9]{6}$/.test(room.room_code)) throw new Error(`Invalid room_code format: ${room.room_code}`);
  if (room.players.length !== 1) throw new Error(`Expected exactly 1 player in room, got ${room.players.length}`);
  if (room.player.name !== 'Sherlock' || !room.player.is_host) throw new Error('Host player profile mismatch');
  console.log(`   SUCCESS: Room created with code: ${room.room_code}`);

  console.log('3. Signing in Guest 2 anonymously...');
  const { data: auth2, error: authErr2 } = await client2.auth.signInAnonymously();
  if (authErr2) throw new Error(`Guest 2 sign-in failed: ${authErr2.message}`);
  const user2 = auth2.user;
  console.log(`   Guest 2 signed in. UID: ${user2.id}`);

  console.log(`4. Invoking game-action (join room ${room.room_code})...`);
  const { data: joinData, error: joinErr } = await client2.functions.invoke('game-action', {
    body: { action: 'join', code: room.room_code, name: 'Watson', avatar: '🐸' }
  });
  if (joinErr) throw new Error(`Join room error: ${JSON.stringify(joinErr)} Data: ${JSON.stringify(joinData)}`);
  if (joinData?.error) throw new Error(`Join room API error: ${joinData.error}`);
  console.log('   Join room response:', JSON.stringify(joinData, null, 2));

  if (joinData.room.players.length !== 2) throw new Error(`Expected 2 players after join, got ${joinData.room.players.length}`);
  console.log(`   SUCCESS: Guest joined room. Total players: ${joinData.room.players.length}`);

  console.log('5. Cleaning up test room...');
  await client1.functions.invoke('game-action', {
    body: { action: 'leave', code: room.room_code }
  });
  console.log('   Host left room.');
  console.log('ALL VERIFICATIONS PASSED SUCCESSFULLY!');
}

run().catch(err => {
  console.error('VERIFICATION FAILED:', err);
  process.exit(1);
});
