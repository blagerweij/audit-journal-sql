-- first create a VIEW on information_schema.columns, so we can select which tables are journalled.
CREATE OR REPLACE VIEW journal_columns AS
SELECT * FROM information_schema.COLUMNS
WHERE (TABLE_SCHEMA = 'program' AND TABLE_NAME IN ('program','agent'))
--   OR (TABLE_SCHEMA = 'claim' AND TABLE_NAME IN ('invoice', 'invoice_item', 'program'))
;

-- now create the SQL statements to create (or alter) the journal tables, and the triggers.
select
       concat(jn.ddl,char(13),
              'DROP TRIGGER IF EXISTS `',jn.table_schema,'`.`',jn.table_name,'_ins`;',char(13),
              'DROP TRIGGER IF EXISTS `',jn.table_schema,'`.`',jn.table_name,'_upd`;',char(13),
              'DROP TRIGGER IF EXISTS `',jn.table_schema,'`.`',jn.table_name,'_del`;',char(13),
              'CREATE TRIGGER `',jn.table_schema,'`.`',jn.table_name,'_ins` AFTER INSERT ON `',jn.table_name,'` FOR EACH ROW ',
              'INSERT INTO `',jn.table_schema,'`.`',jn.table_name,'_jn','` (aud_operation,aud_user,',c.columns,') values (''I'',USER(),',new_columns, ');',char(13),
              'CREATE TRIGGER `',jn.table_schema,'`.`',jn.table_name,'_upd` AFTER UPDATE ON `',jn.table_name,'` FOR EACH ROW ',
              'INSERT INTO `',jn.table_schema,'`.`',jn.table_name,'_jn','` (aud_operation,aud_user,',c.columns,') values (''U'',USER(),',new_columns, ');',char(13),
              'CREATE TRIGGER `',jn.table_schema,'`.`',jn.table_name,'_del` AFTER DELETE ON `',jn.table_name,'` FOR EACH ROW ',
              'INSERT INTO `',jn.table_schema,'`.`',jn.table_name,'_jn','` (aud_operation,aud_user,',c.columns,') values (''D'',USER(),',old_columns, ');',char(13),
           char(13)) as query
from (
    select
      c.table_schema,
      c.table_name,
      concat('CREATE TABLE `',table_schema,'`.`',table_name,'_jn','` (aud_operation CHAR(1), aud_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP, aud_user VARCHAR(255),',
             group_concat(concat('`',column_name,'`',' ',COLUMN_TYPE) order by ordinal_position separator ','),');') ddl
    from journal_columns c
    where not exists (select 1 from information_schema.TABLES t where t.TABLE_SCHEMA = c.TABLE_SCHEMA and t.TABLE_NAME = concat(c.TABLE_NAME,'_jn'))
    group by c.table_schema,c.table_name
    union all
    select
        c.table_schema,
        c.table_name,
        concat('ALTER TABLE `',table_schema,'`.`',table_name,'_jn','` ',
               group_concat(concat('ADD COLUMN `',column_name,'`',' ',COLUMN_TYPE) order by ordinal_position separator ','),';') ddl
    from journal_columns c
    where exists (select 1 from information_schema.TABLES t where t.TABLE_SCHEMA = c.TABLE_SCHEMA and t.TABLE_NAME = concat(c.TABLE_NAME,'_jn'))
      and not exists (select 1 from information_schema.COLUMNS a where a.TABLE_SCHEMA = c.TABLE_SCHEMA and a.TABLE_NAME = concat(c.TABLE_NAME,'_jn') and a.COLUMN_NAME = c.COLUMN_NAME)
    group by c.table_schema,c.table_name
) jn
join (
    select
           table_schema,
           table_name,
           group_concat(concat('`',column_name,'`') order by ordinal_position separator ',') columns,
           group_concat(concat('old.`',column_name,'`') order by ordinal_position separator ',') old_columns,
           group_concat(concat('new.`',column_name,'`') order by ordinal_position separator ',') new_columns
    from information_schema.COLUMNS
    group by table_schema, table_name
) c on jn.TABLE_SCHEMA = c.TABLE_SCHEMA and jn.TABLE_NAME = c.TABLE_NAME;

