import { createClient } from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL, key=import.meta.env.VITE_SUPABASE_ANON_KEY;
export const configured=Boolean(url&&key&&!url.includes('YOUR_PROJECT'));
export const supabase=configured?createClient(url,key,{auth:{autoRefreshToken:true,persistSession:true,detectSessionInUrl:true},realtime:{params:{eventsPerSecond:8}}}):null;
export async function ensureGuest(){if(!supabase)throw new Error('Supabase is not configured. Add the project URL and publishable key to .env.local.');const {data:{session}}=await supabase.auth.getSession();if(session)return session.user;const {data,error}=await supabase.auth.signInAnonymously();if(error)throw error;return data.user}
export async function gameAction(action,payload={}){await ensureGuest();const {data,error}=await supabase.functions.invoke('game-action',{body:{action,...payload}});if(error)throw new Error(data?.error||error.message||'The game could not complete that action.');if(data?.error)throw new Error(data.error);return data}
