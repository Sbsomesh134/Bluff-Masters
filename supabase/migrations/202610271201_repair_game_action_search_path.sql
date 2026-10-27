-- Repair search_path for public.game_action to correctly include the pgcrypto extension schema and public
DO $migration$
DECLARE
  v_crypto_schema text;
  v_probe bytea;
BEGIN
  SELECT n.nspname
    INTO v_crypto_schema
    FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace
   WHERE e.extname = 'pgcrypto';

  IF v_crypto_schema IS NULL THEN
    RAISE EXCEPTION 'pgcrypto is not installed';
  END IF;

  IF to_regprocedure(
    format('%I.gen_random_bytes(integer)', v_crypto_schema)
  ) IS NULL THEN
    RAISE EXCEPTION
      'gen_random_bytes(integer) not found in schema %',
      v_crypto_schema;
  END IF;

  EXECUTE format(
    'SELECT %I.gen_random_bytes(3)',
    v_crypto_schema
  ) INTO v_probe;

  IF octet_length(v_probe) <> 3 THEN
    RAISE EXCEPTION 'Unexpected random byte result';
  END IF;

  -- Set search_path without single-quote encapsulation so PostgreSQL parses it as a list of schemas.
  -- Keeps public for game tables and procedures, extension schema for pgcrypto, and pg_temp last.
  EXECUTE format(
    'ALTER FUNCTION public.game_action(uuid,text,text,jsonb) SET search_path = public, %I, pg_temp',
    v_crypto_schema
  );
END
$migration$;

REVOKE ALL ON FUNCTION public.game_action(uuid,text,text,jsonb) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.game_action(uuid,text,text,jsonb) TO service_role;
