import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') || '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};
const reply=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:cors});
Deno.serve(async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(req.method!=='POST')return reply({error:'Use POST for game actions.'},405);
  try{
    const auth=req.headers.get('Authorization');
    if(!auth?.startsWith('Bearer '))return reply({error:'Guest sign-in is required.'},401);
    const url=Deno.env.get('SUPABASE_URL');
    const anon=Deno.env.get('SUPABASE_ANON_KEY')||Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
    const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if(!url||!anon||!service)return reply({error:'The game server is missing Supabase configuration.'},500);
    const token=auth.slice(7);
    const identity=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data:{user},error:authError}=await identity.auth.getUser(token);
    if(authError||!user)return reply({error:'Your guest session expired. Refresh the page to reconnect.'},401);
    const body=await req.json();
    const allowed=new Set(['create','join','state','ready','start','submit','vote','advance','next','rematch','leave','kick','report']);
    if(!allowed.has(body.action))return reply({error:'Unknown game action.'},400);
    const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data,error}=await admin.rpc('game_action',{
      p_user:user.id,
      p_action:body.action,
      p_code:typeof body.code==='string'?body.code:null,
      p_payload:body,
    });
    if(error){
      const message=error.message||'The game action failed.';
      return reply({error:message.replace(/^.*?ERROR:\s*/,'').replace(/^P0001:\s*/,'')},400);
    }
    return reply(data||{room:null});
  }catch(e){
    console.error('game-action failed',e);
    return reply({error:'The game server could not complete that action. Please try again.'},500);
  }
});

