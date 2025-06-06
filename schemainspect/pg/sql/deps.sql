
with things1 as (
  select
    oid as objid,
    pronamespace as namespace,
    proname as name,
    pg_get_function_identity_arguments(oid) as identity_arguments,
    'f' as kind
  from pg_proc
  -- 11_AND_LATER where pg_proc.prokind != 'a'
  -- 10_AND_EARLIER where pg_proc.proisagg is False
  union
  select
    oid,
    relnamespace as namespace,
    relname as name,
    null as identity_arguments,
    relkind as kind
  from pg_class
  where oid not in (
    select ftrelid from pg_foreign_table
  )
  union
  select
    oid,
    typnamespace as namespace,
    typname as name,
    null as identity_arguments,
    'e' as kind
  from pg_type
  where typtype = 'e' and typelem = 0
),
extension_objids as (
  select
      objid as extension_objid
  from
      pg_depend d
  WHERE
      d.refclassid = 'pg_extension'::regclass
    union
    select
        t.typrelid as extension_objid
    from
        pg_depend d
        join pg_type t on t.oid = d.objid
    where
        d.refclassid = 'pg_extension'::regclass
),
things as (
    select
      objid,
      kind,
      n.nspname as schema,
      name,
      identity_arguments
    from things1 t
    inner join pg_namespace n
      on t.namespace = n.oid
    left outer join extension_objids
      on t.objid = extension_objids.extension_objid
    where
      kind in ('r', 'v', 'm', 'c', 'f', 'e') and
      nspname not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
      and nspname not like 'pg_temp_%' and nspname not like 'pg_toast_temp_%'
      and extension_objids.extension_objid is null
),
selectable_deps as (
  select distinct
    t.objid,
    t.schema,
    t.name,
    t.identity_arguments,
    t.kind,
    things_dependent_on.objid as objid_dependent_on,
    things_dependent_on.schema as schema_dependent_on,
    things_dependent_on.name as name_dependent_on,
    things_dependent_on.identity_arguments as identity_arguments_dependent_on,
    things_dependent_on.kind as kind_dependent_on
  FROM
      pg_depend d
      inner join things things_dependent_on
        on d.refobjid = things_dependent_on.objid
      inner join pg_rewrite rw
        on d.objid = rw.oid
        and things_dependent_on.objid != rw.ev_class
      inner join things t
        on rw.ev_class = t.objid
  where
    d.deptype in ('n')
    and
    rw.rulename = '_RETURN'
),
func_deps as (
  select distinct
    t.objid,
    t.schema,
    t.name,
    t.identity_arguments,
    t.kind,
    things_dependent_on.objid as objid_dependent_on,
    things_dependent_on.schema as schema_dependent_on,
    things_dependent_on.name as name_dependent_on,
    things_dependent_on.identity_arguments as identity_arguments_dependent_on,
    things_dependent_on.kind as kind_dependent_on
  from
    pg_depend d
    join things things_dependent_on
      on d.refobjid = things_dependent_on.objid
    join things t
      on d.objid = t.objid
    left join pg_rewrite rw
      on rw.ev_class = t.objid and rw.rulename = '_RETURN'
  where
    t.kind = 'f'
    and d.deptype = 'n'
    and t.kind = 'f' 
    
),
combined as (
  select distinct * from (
    select * from func_deps union
    select * from selectable_deps
  ) as deps_union
)
select * from combined
order by
schema, name, identity_arguments, kind_dependent_on,
schema_dependent_on, name_dependent_on, identity_arguments_dependent_on
