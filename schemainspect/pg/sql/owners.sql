WITH owners AS (
  SELECT 
    CASE c.relkind
      WHEN 'r' THEN 'table'
      WHEN 'v' THEN 'view'
      WHEN 'm' THEN 'materialized view'
      WHEN 'i' THEN 'index'
      WHEN 'S' THEN 'sequence'
      WHEN 'f' THEN 'foreign table'
      ELSE 'other'
    END AS objtype,
    n.nspname,
    c.relname AS objname,
    NULL AS objsubname,
    r.rolname AS owner
  FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_roles r ON c.relowner = r.oid
  WHERE c.relkind IN ('r', 'v', 'm', 'i', 'S', 'f')
    -- SKIP_INTERNAL AND n.nspname NOT LIKE 'pg_%'
    -- SKIP_INTERNAL AND n.nspname != 'information_schema'

  UNION ALL

  SELECT
    'function' AS objtype,
    n.nspname,
    p.proname AS objname,
    pg_get_function_identity_arguments(p.oid) AS objsubname,
    r.rolname AS owner
  FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_roles r ON p.proowner = r.oid
  -- SKIP_INTERNAL WHERE n.nspname NOT LIKE 'pg_%'
    -- SKIP_INTERNAL AND n.nspname != 'information_schema'

  UNION ALL

  SELECT
    'type' AS objtype,
    n.nspname,
    t.typname AS objname,
    NULL AS objsubname,
    r.rolname AS owner
  FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    JOIN pg_roles r ON t.typowner = r.oid
  WHERE t.typtype = 'c'
    -- SKIP_INTERNAL AND n.nspname NOT LIKE 'pg_%'
    -- SKIP_INTERNAL AND n.nspname != 'information_schema'
)

SELECT * FROM owners
ORDER BY
  CASE objtype
    WHEN 'table' THEN 0
    WHEN 'view' THEN 1
    WHEN 'function' THEN 999
    ELSE length(objtype)
  END,
  nspname, objname;
