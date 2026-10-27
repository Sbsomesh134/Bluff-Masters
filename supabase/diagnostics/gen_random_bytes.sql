SELECT
    e.extname,
    n.nspname AS extension_schema
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
WHERE e.extname = 'pgcrypto';

SELECT
    to_regprocedure(
        'public.game_action(uuid,text,text,jsonb)'
    ) AS game_action_function;

SELECT
    p.oid::regprocedure AS function_signature,
    p.proconfig AS function_settings
FROM pg_proc p
WHERE p.oid =
    to_regprocedure('public.game_action(uuid,text,text,jsonb)');

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'gen_random_bytes';