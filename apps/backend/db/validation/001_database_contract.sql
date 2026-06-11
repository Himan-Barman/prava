-- Prava database contract validation.
-- Run after migrations and seeds. This script fails when a required check fails.

\set ON_ERROR_STOP on

SELECT *
FROM prava_validate_database_contract()
ORDER BY check_name;

DO $$
DECLARE
  failed_checks text;
BEGIN
  SELECT string_agg(check_name, ', ' ORDER BY check_name)
  INTO failed_checks
  FROM prava_validate_database_contract()
  WHERE passed = false;

  IF failed_checks IS NOT NULL THEN
    RAISE EXCEPTION 'Prava database contract validation failed: %', failed_checks;
  END IF;
END;
$$;
