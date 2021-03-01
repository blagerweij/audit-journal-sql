-- create the journal tables:
DECLARE
    s VARCHAR2(3000);
    CURSOR c1 IS
        SELECT a.table_name 
        FROM user_tables a
        WHERE NOT EXISTS (SELECT 1 FROM user_tables WHERE table_name = SUBSTR(a.table_name,1,26) || '$JN') -- audit table already present
        AND table_name NOT LIKE '%$JN' -- exclude audit tables
        AND table_name IN ('ALBUM'); -- add inclusion/exclusion here
    CURSOR c2(p_table USER_TABLES.TABLE_NAME%TYPE) IS 
        SELECT column_name,data_type,data_length,data_precision,data_scale
        FROM user_tab_columns 
        WHERE table_name  = p_table 
        ORDER BY column_id; 
BEGIN
    FOR tab IN c1 LOOP 
        s := 'CREATE TABLE ' || SUBSTR(tab.table_name,1,26) || '$JN(jn_operation CHAR(3),jn_datetime DATE,jn_host VARCHAR(100), jn_user VARCHAR(100)';
        FOR col IN c2(tab.table_name) LOOP 
            s := s || ',"' || col.column_name || '" ' || col.data_type;
            IF col.data_type = 'NUMBER'  THEN
                IF col.data_precision IS NOT NULL THEN
                    s := s || '(' || col.data_precision||',' || col.data_scale||')';
                END IF;
            ELSIF col.data_type IN ('CHAR','VARCHAR','VARCHAR2')  THEN 
                s := s || '(' || col.data_length||')';
            END IF;          
        END LOOP; 
        s := s || ')';
        EXECUTE IMMEDIATE s;
    END LOOP; 
END;
/

-- recreate the triggers:
DECLARE
  colnames VARCHAR2(3000);
  newnames VARCHAR2(3000);
  oldnames VARCHAR2(3000);
  CURSOR c_tab IS
    SELECT a.table_name 
      FROM user_tables a
      INNER JOIN user_tables b ON SUBSTR(a.table_name,1,26) || '$JN' = b.table_name;
  CURSOR c_col(p_table USER_TABLES.TABLE_NAME%TYPE) IS 
    SELECT column_name 
      FROM user_tab_columns 
      WHERE table_name  = p_table
      AND column_name NOT IN ('JN_ACTION','JN_DATETIME','JN_HOST','JN_USER') 
      ORDER BY column_id;  
BEGIN
  FOR tab IN c_tab LOOP 
  dbms_output.put_line(tab.table_name);
    colnames := '';
    newnames := '';
    oldnames := '';
    FOR col IN c_col(tab.table_name) LOOP      
      colnames := colnames || ',"' || col.column_name || '"';
      newnames := newnames || ',:new."' || col.column_name || '"';
      oldnames := oldnames || ',:old."' || col.column_name || '"';
    END LOOP;
    execute immediate 'CREATE OR REPLACE TRIGGER ' || SUBSTR(tab.table_name,1,26)||'$INS '||
     ' AFTER INSERT ON ' || tab.table_name ||
     ' FOR EACH ROW' || CHR(10) || 
         'BEGIN' || CHR(10) ||
        '    INSERT INTO '||SUBSTR(tab.table_name,1,26) || '$JN (' ||
        '      jn_operation,jn_datetime,jn_host,jn_user' ||
        colnames || ') values (''INS'',sysdate,sys_context(''USERENV'',''HOST''),sys_context(''USERENV'',''OS_USER'')' || newnames ||
     ');' ||CHR(10) || 'END;';
  
    execute immediate 'CREATE OR REPLACE TRIGGER ' || SUBSTR(tab.table_name,1,26)||'$UPD '||
     ' AFTER UPDATE '|| 'ON ' || tab.table_name ||
     ' FOR EACH ROW' || CHR(10) || 
         'BEGIN' || CHR(10) ||
        '    INSERT INTO '||SUBSTR(tab.table_name,1,26) || '$JN (' ||
        '      jn_operation,jn_datetime,jn_host,jn_user' ||
        colnames || ') values (''UPD'',sysdate,sys_context(''USERENV'',''HOST''),sys_context(''USERENV'',''OS_USER'')' || newnames ||
     ');' ||CHR(10) || 'END;';
    execute immediate 'CREATE OR REPLACE TRIGGER ' || SUBSTR(tab.table_name,1,26)||'$DEL '||
     ' AFTER DELETE '|| 'ON ' || tab.table_name ||
     ' FOR EACH ROW' || CHR(10) || 
         'BEGIN' || CHR(10) ||
        '    INSERT INTO '||SUBSTR(tab.table_name,1,26) || '$JN (' ||
        '      jn_operation,jn_datetime,jn_host,jn_user' ||
        colnames || ') values (''DEL'',sysdate,sys_context(''USERENV'',''HOST''),sys_context(''USERENV'',''OS_USER'')' || oldnames ||
     ');' ||CHR(10) || 'END;';
           
  END LOOP; 
END;
/
