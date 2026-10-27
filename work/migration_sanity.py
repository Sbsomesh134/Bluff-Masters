from pathlib import Path
p=Path('supabase/migrations/202610271200_fix_gen_random_bytes_search_path.sql')
s=p.read_text(encoding='utf-8-sig')
s=s.replace('  v_crypto_schema text;\nbegin', '  v_crypto_schema text;\n  v_probe bytea;\nbegin')
s=s.replace("  if v_crypto_schema is null then\n    raise exception 'pgcrypto is not installed; room-code generation cannot be repaired';\n  end if;\n\n  execute format(", "  if v_crypto_schema is null then\n    raise exception 'pgcrypto is not installed; room-code generation cannot be repaired';\n  end if;\n\n  if to_regprocedure(format('%I.gen_random_bytes(integer)', v_crypto_schema)) is null then\n    raise exception 'pgcrypto exists in schema %, but gen_random_bytes(integer) is missing', v_crypto_schema;\n  end if;\n\n  execute format('select %I.gen_random_bytes(3)', v_crypto_schema) into v_probe;\n  if octet_length(v_probe)<>3 then\n    raise exception 'pgcrypto gen_random_bytes(integer) returned an unexpected result';\n  end if;\n\n  execute format(")
p.write_text(s,encoding='utf-8')
