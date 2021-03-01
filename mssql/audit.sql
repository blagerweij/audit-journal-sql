DECLARE @tablename SYSNAME
DECLARE @tables_cursor CURSOR
SET @tables_cursor = CURSOR FOR 
  SELECT table_name
    FROM INFORMATION_SCHEMA.TABLES
    WHERE table_name IN ('Relation','Policy','CoverType','Premium')
 
OPEN @tables_cursor
 
FETCH NEXT FROM @tables_cursor INTO @tablename
 
WHILE @@FETCH_STATUS = 0
BEGIN
 
  DECLARE @sql NVARCHAR(3000),
    @field INT,
    @maxfield INT,
    @fieldname SYSNAME,
    @type SYSNAME,
    @length INT,
    @precision INT,
    @scale INT,
    @fields NVARCHAR(3000),
    @columns_cursor CURSOR
 
    SET @columns_cursor = CURSOR FOR
      SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = @tablename
        ORDER BY ORDINAL_POSITION
 
  OPEN @columns_cursor
 
  SET @sql = 'CREATE TABLE ' + @tablename+ '_JN ( jn_operation CHAR(1), jn_datetime DATETIME, jn_host VARCHAR(100), jn_user VARCHAR(100)'
  SET @fields=''
 
  FETCH NEXT FROM @columns_cursor INTO @fieldname, @type, @length, @precision, @scale
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @sql = @sql + ',' + @fieldname+' '+@type
    IF @type IN ('number')
      SET @sql = @sql + '(' + CAST(@precision AS NVARCHAR)+',' + CAST(@scale AS NVARCHAR)+')'
    ELSE IF @type IN ('char','varchar','nvarchar') 
      SET @sql = @sql + '(' + CAST(@length AS NVARCHAR)+')'
    SET @fields = @fields + ',' + @fieldname
