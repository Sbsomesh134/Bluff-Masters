-- Ensure pgcrypto exists and add its schema to the game_action search path.
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

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

  EXECUTE format(
    'ALTER FUNCTION public.game_action(uuid,text,text,jsonb) SET search_path TO %L',
    format('pg_catalog, %I, public, pg_temp', v_crypto_schema)
  );
END
$migration$;