select
  current_setting('search_path') as session_search_path,
  (select n.nspname from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname='pgcrypto') as pgcrypto_schema,
  (select e.extversion from pg_extension e where e.extname='pgcrypto') as pgcrypto_version,
  to_regprocedure('gen_random_bytes(integer)')::text as gen_random_bytes_visible_in_session,
  to_regprocedure('extensions.gen_random_bytes(integer)')::text as extension_schema_function,
  to_regprocedure('public.gen_random_bytes(integer)')::text as public_schema_function,
  p.oid::regprocedure::text as deployed_function,
  p.prosecdef as security_definer,
  p.proconfig as function_settings,
  (pg_get_functiondef(p.oid) like '%gen_random_bytes%') as function_calls_gen_random_bytes,
  regexp_match(pg_get_functiondef(p.oid), E'[^\\n]*gen_random_bytes[^\\n]*') as call_site
from pg_proc p
where p.oid='public.game_action(uuid,text,text,jsonb)'::regprocedure;
