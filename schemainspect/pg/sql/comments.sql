WITH comms AS (
	SELECT CASE relkind
				WHEN 'r' THEN 'table'
				WHEN 'i' THEN 'index'
				WHEN 'S' THEN 'sequence'
				WHEN 'v' THEN 'view'
				WHEN 'm' THEN 'materialized view'
				WHEN 'c' THEN 'type'
				WHEN 'f' THEN 'foreign table'
			END AS objtype,
			nsp.nspname, cls.relname AS objname, NULL AS objsubname, 0 AS objsubid,
			d.description 
		FROM pg_catalog.pg_class cls
			JOIN pg_catalog.pg_namespace nsp ON (nsp.oid = cls.relnamespace)
			JOIN pg_catalog.pg_description d ON (d.objoid = cls.oid AND d.objsubid = 0 AND d.classoid = 'pg_catalog.pg_class'::regclass)
	UNION ALL
	SELECT 'function' AS objtype, n.nspname, p.proname AS objname,
			pg_catalog.pg_get_function_identity_arguments(p.oid) AS objsubname, 0 AS objsubid,
			d.description
		FROM pg_catalog.pg_proc p
		    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
			JOIN pg_catalog.pg_description d ON (d.objoid = p.oid AND d.objsubid = 0 AND d.classoid = 'pg_catalog.pg_proc'::regclass)
		-- SKIP_INTERNAL WHERE n.nspname NOT IN ('pg_catalog','information_schema')
	UNION ALL
	SELECT 'column' as objtype, nsp.nspname, cls.relname AS objname, att.attname AS objsubname, d.objsubid,
			d.description
		FROM pg_catalog.pg_attribute att
			JOIN pg_catalog.pg_class cls ON (cls.oid = att.attrelid)
			JOIN pg_catalog.pg_namespace nsp ON (nsp.oid = cls.relnamespace)
			JOIN pg_catalog.pg_description d ON (d.objoid = cls.oid AND d.objsubid = att.attnum AND d.classoid = 'pg_catalog.pg_class'::regclass)
		WHERE NOT att.attisdropped
	UNION ALL
	SELECT 'trigger' AS objtype, n.nspname, rel.relname,
			tr.tgname AS objsubname, 0 AS objsubid,
			d.description
		FROM pg_catalog.pg_trigger tr
			JOIN pg_catalog.pg_class rel ON rel.oid = tr.tgrelid
		    JOIN pg_catalog.pg_namespace n ON n.oid = rel.relnamespace
			JOIN pg_catalog.pg_description d ON (d.objoid = tr.oid AND d.objsubid = 0 AND d.classoid = 'pg_catalog.pg_trigger'::regclass)
	UNION ALL
	SELECT 'constraint' AS objtype, n.nspname, rel.relname,
			con.conname AS objsubname, 0 AS objsubid,
			d.description
		FROM pg_catalog.pg_constraint con
			JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid
		    JOIN pg_catalog.pg_namespace n ON n.oid = rel.relnamespace
			JOIN pg_catalog.pg_description d ON (d.objoid = con.oid AND d.objsubid = 0 AND d.classoid = 'pg_catalog.pg_constraint'::regclass)
)
SELECT * FROM comms
ORDER BY
	CASE objtype
		WHEN 'table' THEN 0
		WHEN 'column' THEN 0
		WHEN 'function' THEN 999
		ELSE length(objtype)
	END,
	nspname, objname, objsubid;
