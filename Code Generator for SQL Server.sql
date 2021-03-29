USE School;
GO

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRY

DECLARE @TableName              NVARCHAR (60)  =  'Student',
        @SchemaName             NVARCHAR (60)  =  '',
        @Comments               NVARCHAR (200) =  'Grupo de estudiantes',
        @NumberCol              INT            =  0,
        @SqlHeader              VARCHAR(MAX)   =  '',
        @sqlTriggerAction       NVARCHAR (60)  =  '',
        @SqlTriggerDelete       VARCHAR(MAX)   =  '',
        @SqlTriggerUpdate       VARCHAR(MAX)   =  '',
        @SqlTriggerInsert       VARCHAR(MAX)   =  '',
        @SqlRBTriggerDelete     VARCHAR(MAX)   =  '',
        @SqlRBTriggerUpdate     VARCHAR(MAX)   =  '',
        @SqlRBTriggerInsert     VARCHAR(MAX)   =  '',
        @SqlRBTable             NVARCHAR(200)  =  '',
        @SqlRBspGet             VARCHAR(MAX)   =  '',
        @SqlRBspLoad            VARCHAR(MAX)   =  ''

SET @SqlHeader = '/*====================================================================================================================================
 a) Proyecto y/o Aplicación:                   School / OutComes
 b) Autor/ Gerencia de adscripción:            Homero Ibarra / TI
 c) Fecha de Creacion:                         ' + CONVERT(VARCHAR(11),GETDATE(),105) + '
 d) Objetivo:                                  ' + @Comments + '
 e) Version:                                   1.0.0.0
 f) Historico de Modificaciones:
    i.   Modificación:                         001
    ii.  Modificó / Gerencia de adscripción:   
    iii. Fecha:                                
    iv.  Objetivo:                             
    v.   Versión:   						   
    
 g) Parametros:
====================================================================================================================================*/'

IF ( @SchemaName = '' OR @SchemaName IS NULL )
BEGIN SET @SchemaName = 'dbo' END

IF NOT EXISTS ( SELECT t.name AS TableName FROM sys.tables t INNER JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE t.type = 'U' AND t.name = @TableName AND s.name = @SchemaName )
BEGIN
   RAISERROR (N'No existe tabla: %s', -1,-1, @TableName );
   RETURN;
END

IF ( SUBSTRING(@TableName, 1, 3) = 'Log_' )
BEGIN
   RAISERROR (N'No se puede generar código para la tabla de registro: %s', -1,-1, @TableName );
   RETURN;
END

DECLARE Tables_Cursor CURSOR READ_ONLY
FOR
SELECT     t.name AS TableName, COUNT(c.column_id) AS NumberCol, s.name AS SchemaName
FROM       sys.tables       t
INNER JOIN sys.schemas      s  ON t.schema_id = s.schema_id
INNER JOIN sys.all_columns  c  ON t.object_id = c.object_id
WHERE      t.type = 'U' --AND              t.name NOT LIKE 'Log_%'
AND        t.name = @TableName 
AND        s.name = @SchemaName --AND t.name NOT IN ('__RefactorLog', 'sysdiagrams')
GROUP BY   t.name, s.name

OPEN Tables_Cursor
FETCH NEXT FROM Tables_Cursor INTO @TableName, @NumberCol, @SchemaName
WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @SqlspGet              VARCHAR(MAX)  = '',
                @SqlUpdate             VARCHAR(MAX)  = '',
                @SqlDelete             VARCHAR(MAX)  = '',
                @ColumnName            VARCHAR(MAX)  = '',
                @DataType              NVARCHAR(20)  = '',
                @ColumnLen             NVARCHAR(8)   = '',
                @isIdentity            BIT           = 0,
                @Scale                 NVARCHAR(8)   = '',
                @IsNullable            BIT           = 0,
                @ColCount              INT           = 1,
                @Columns               VARCHAR(MAX)  = '',
                @ColumnsBracket        VARCHAR(MAX)  = '',
                @ColumnsParameter      VARCHAR(MAX)  = '',
                @ColumnsParameterType  VARCHAR(MAX)  = '',
                @ColumnsFusion         VARCHAR(MAX)  = '',
                @ColumnsValue          VARCHAR(MAX)  = '',
                @ColumnTypeRequired    VARCHAR(MAX)  = '',
                @ColumnPK              NVARCHAR(60)  = '',
                @ColumnPKBracket       NVARCHAR(60)  = '',
                @ColumnPKParameter     NVARCHAR(60)  = '',
                @ColumnPKParameterType NVARCHAR(60)  = '',
                @ColumnPKTypeRequired  NVARCHAR(60)  = '',
                @ExtendeProperty       VARCHAR(MAX)  = '' 
        --PRINT @TableName
        DECLARE Columns_Cursor CURSOR READ_ONLY
        FOR
        SELECT      c.name, UPPER(ty.name) AS dataType, c.max_length, c.is_identity, c.scale, c.is_nullable--, * 
        FROM        sys.all_columns         c 
        INNER JOIN  sys.types               ty  ON c.system_type_id = ty.system_type_id
        LEFT JOIN   sys.foreign_key_columns fk  ON c.object_id = fk.parent_object_id AND c.column_id = fk.parent_column_id
        LEFT JOIN   sys.tables              tfk ON fk.referenced_object_id = tfk.object_id
        LEFT JOIN   sys.columns             cfk ON tfk.object_id = cfk.object_id AND cfk.column_id = referenced_column_id
        WHERE c.object_id = object_id(@SchemaName + '.' + @TableName)--('AccountAddress')
        AND   ty.name NOT IN ('sysname')
        ORDER BY c.column_id           

        OPEN Columns_Cursor
        FETCH NEXT FROM Columns_Cursor INTO @ColumnName, @DataType, @ColumnLen, @isIdentity, @Scale, @IsNullable
        WHILE @@FETCH_STATUS = 0
            BEGIN 
                DECLARE @ColumnAuxBracket       NVARCHAR(MAX) = '',
                        @ColumnsValueAux        NVARCHAR(MAX) = '',
                        @ColumnAuxParameter     NVARCHAR(MAX) = '',
                        @ColumnAuxParameterType NVARCHAR(MAX) = '',
                        @ColumnAuxFusion        NVARCHAR(MAX) = '',
                        @ColumnAuxTypeRequired  NVARCHAR(MAX) = '',
                        @sqlStatement           NVARCHAR(MAX) = '',
                        @fkID                   VARCHAR(25)   = ''
                --PRINT '   ' + @ColumnName -- PRINT @Columns
                IF ( @isIdentity = 1 )
                BEGIN 
                    SET @ColumnPK = N'[' + @ColumnName + N']';
                    SET @ColumnPKParameter = N'@' + @ColumnName;
                    SET @ColumnPKParameterType = N'@' + @ColumnName + ' ' + @DataType
                    --SET @ColumnPKTypeRequired = N'@' + 
                END
                  
                IF ( @ColumnPK = N'' AND @ColCount = 1 )
                BEGIN
                    SET @ColumnPK = N'[' + @ColumnName + N']';
                    SET @ColumnPKParameter = N'@' + @ColumnName;
                    SET @ColumnPKParameterType = N'@' + @ColumnName + ' ' + @DataType
                END  
                          
                IF ( @ColCount < @NumberCol )
                BEGIN                                  
                    IF ( @isIdentity = 0 )
                    BEGIN
                        SET @ColumnAuxBracket = N'['+ @ColumnName + '], '
                        SET @ColumnAuxParameter = N'@'+ @ColumnName + ', '
                        SET @ColumnAuxParameterType = N'@'+ @ColumnName + ' ' + CHAR(9) + CHAR(9) + @DataType + CASE WHEN CHARINDEX('char', @DataType ) > 0 THEN '(' + @ColumnLen + ')' 
                                                                                                            WHEN CHARINDEX('off', @DataType ) > 0  THEN '(' + @Scale + ')' ELSE ',' END + CHAR(9) +
                                                                                                            CASE WHEN @IsNullable = 1 THEN 'NULL,' ELSE ' NOT NULL,' END + CHAR(13)
                        SET @ColumnAuxFusion = REPLACE(@ColumnAuxBracket, ',', '') + ' = ' + @ColumnAuxParameter + CHAR(13)
                        SET @ColumnAuxTypeRequired = CHAR(9) + N'['+ @ColumnName + '] ' + CHAR(9) + CHAR(9) + @DataType + + CASE WHEN CHARINDEX('char', @DataType ) > 0 THEN '(' + @ColumnLen + ')' 
                                                                                                WHEN CHARINDEX('off', @DataType ) > 0  THEN '(' + @Scale + ')' ELSE '' END + CHAR(9) +
                                                                                                CASE WHEN @IsNullable = 1 THEN 'NULL,' ELSE ' NOT NULL,' END + CHAR(13)
                    END
                END
                ELSE
                BEGIN                
                    SET @ColumnAuxBracket = N'['+ @ColumnName + ']'
                    SET @ColumnAuxParameter = N'@'+ @ColumnName
                    SET @ColumnAuxParameterType = N'@'+ @ColumnName + ' ' +  CHAR(9) + @DataType + CASE WHEN CHARINDEX('char', @DataType ) > 0 THEN '(' + @ColumnLen + ')' 
                                                                                                    WHEN CHARINDEX('off', @DataType ) > 0  THEN '(' + @Scale + ')' ELSE '' END + CHAR(9) +
                                                                                                CASE WHEN @IsNullable = 1 THEN 'NULL,' ELSE ' NOT NULL,' END
                    SET @ColumnAuxFusion = REPLACE(@ColumnAuxBracket, ',', '') + ' = ' + @ColumnAuxParameter
                    SET @ColumnAuxTypeRequired = CHAR(9) + N'['+ @ColumnName + ']' + CHAR(9) + CHAR(9) + @DataType + + CASE WHEN CHARINDEX('char', @DataType ) > 0 THEN '(' + @ColumnLen + ')' 
                                                                                                    WHEN CHARINDEX('off', @DataType ) > 0  THEN '(' + @Scale + ')' ELSE '' END + CHAR(9) +
                                                                                                CASE WHEN @IsNullable = 1 THEN 'NULL,' ELSE ' NOT NULL,' END + CHAR(13)
                END    

                SET @ColumnsParameter = @ColumnsParameter + @ColumnAuxParameter
                SET @ColumnsParameterType = @ColumnsParameterType + CHAR(9) + @ColumnAuxParameterType
                SET @ColumnsBracket = @ColumnsBracket + @ColumnAuxBracket
                SET @ColumnsFusion = @ColumnsFusion + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @ColumnAuxFusion
                SET @ColumnTypeRequired = @ColumnTypeRequired + @ColumnAuxTypeRequired
                SET @ColCount = @ColCount + 1   

                IF NOT EXISTS (SELECT major_id, minor_id, t.name AS [Table Name], c.name AS [Column Name], value AS [Extended Property]
                               FROM sys.extended_properties AS ep
                               INNER JOIN sys.tables        AS t ON ep.major_id = t.object_id 
                               INNER JOIN sys.columns       AS c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
                               WHERE t.name = @TableName AND   c.name = @ColumnName )
                BEGIN                                  
                    IF NOT ( @ColumnName IN ('BeginDate', 'BeginDateTime', 'EndDate', 'EndDateTime', 'CreatedBy', 'CreateDate', 'CreateDateTime', 'CreatedDate', 'CreatedDateTime') )
                    BEGIN
                        SET @ExtendeProperty = @ExtendeProperty + 'EXECUTE sp_addextendedproperty @name = N''MS_Description'', @value = N''' + @ColumnName + ''', @level0type = N''SCHEMA'', @level0name = N''' + @SchemaName + ''', @level1type = N''TABLE'', @level1name = N''' + @TableName + ''', @level2type = N''COLUMN'', @level2name = N''' + @ColumnName + ''';
GO
'                   END
                END
            FETCH NEXT FROM Columns_Cursor INTO @ColumnName, @DataType, @ColumnLen, @isIdentity, @Scale, @IsNullable
        END                                                      
        CLOSE Columns_Cursor
        DEALLOCATE Columns_Cursor                 
        FETCH NEXT FROM Tables_Cursor INTO @TableName, @NumberCol, @SchemaName
    END          
CLOSE Tables_Cursor
DEALLOCATE Tables_Cursor

-- Inner Join Down
DECLARE @TableNameDownMain    NVARCHAR (60) = @TableName,
        @SchemaNameDownMain   NVARCHAR (60) = @SchemaName,
        @ColumnDownMain       NVARCHAR (60) = '',
        @fkTableDown          VARCHAR(MAX)  = '',
        @fkColumnDown         VARCHAR(MAX)  = '',
        @fkSchemaNameDown     VARCHAR(60)   = '',
        @NumberTablesDown     INT           = 2,
        @TableJoinNamesDown   NVARCHAR(MAX) = '',                
        @ColumnsJoinDown      VARCHAR(MAX)  = ''
        
DECLARE TablesJoinDown_Cursor CURSOR READ_ONLY
FOR
SELECT      c.name, tfk.name, cfk.name, sfk.name
FROM        sys.all_columns         c 
INNER JOIN  sys.types               ty  ON c.system_type_id         =  ty.system_type_id
LEFT JOIN   sys.foreign_key_columns fk  ON c.object_id              =  fk.parent_object_id AND c.column_id = fk.parent_column_id
LEFT JOIN   sys.tables              tfk ON fk.referenced_object_id  =  tfk.object_id
LEFT JOIN   sys.schemas             sfk ON tfk.schema_id            =  sfk.schema_id
LEFT JOIN   sys.columns             cfk ON tfk.object_id            =  cfk.object_id AND cfk.column_id = referenced_column_id
WHERE c.object_id = object_id(@SchemaNameDownMain + '.' + @TableNameDownMain) 
AND ty.name NOT IN ('sysname') AND tfk.name IS NOT NULL
ORDER BY c.column_id

OPEN TablesJoinDown_Cursor
FETCH NEXT FROM TablesJoinDown_Cursor INTO @ColumnDownMain, @fkTableDown, @fkColumnDown, @fkSchemaNameDown
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @ColumnJoinName        VARCHAR(MAX)  = ''           
                   
    SET @TableJoinNamesDown = @TableJoinNamesDown + 'INNER JOIN [' + @fkSchemaNameDown +'].[' + @fkTableDown + '] ' + CHAR(64 + @NumberTablesDown) + ' WITH (NOLOCK) ON A.' + @ColumnDownMain + ' = ' + CHAR(64 + @NumberTablesDown) + '.' + @fkColumnDown + CHAR(13)
                                                 
    DECLARE ColumnsJoin_Cursor CURSOR READ_ONLY
    FOR
    SELECT      c.name
    FROM        sys.all_columns         c 
    INNER JOIN  sys.types               ty  ON c.system_type_id = ty.system_type_id
    LEFT JOIN   sys.foreign_key_columns fk  ON c.object_id = fk.parent_object_id AND c.column_id = fk.parent_column_id
    LEFT JOIN   sys.tables              tfk ON fk.referenced_object_id = tfk.object_id
    LEFT JOIN   sys.columns             cfk ON tfk.object_id = cfk.object_id AND cfk.column_id = referenced_column_id
    WHERE c.object_id = object_id(@fkSchemaNameDown + '.' + @fkTableDown)
    AND ty.name NOT IN ('sysname')
    ORDER BY c.column_id

    OPEN ColumnsJoin_Cursor
        FETCH NEXT FROM ColumnsJoin_Cursor INTO @ColumnJoinName
        WHILE @@FETCH_STATUS = 0
        BEGIN 
            DECLARE @ColumnJoinAux              NVARCHAR(MAX) = ''
                                
            SET @ColumnJoinAux = CHAR(64 + @NumberTablesDown) + N'.['+ @ColumnJoinName + '], '
            SET @ColumnsJoinDown = @ColumnsJoinDown + @ColumnJoinAux
                                                                                                      
            FETCH NEXT FROM ColumnsJoin_Cursor INTO @ColumnJoinName
        END               
        SET @ColumnsJoinDown = @ColumnsJoinDown + CHAR(13)

    CLOSE ColumnsJoin_Cursor
    DEALLOCATE ColumnsJoin_Cursor

    SET @NumberTablesDown = @NumberTablesDown + 1

    FETCH NEXT FROM TablesJoinDown_Cursor INTO @ColumnDownMain, @fkTableDown, @fkColumnDown, @fkSchemaNameDown
    END     
CLOSE TablesJoinDown_Cursor
DEALLOCATE TablesJoinDown_Cursor

--Inner Join Up
--SELECT      c.name, tfk.name, cfk.name, sfk.name
--FROM        sys.all_columns         c
--LEFT JOIN   sys.foreign_key_columns fk  ON c.object_id              =  fk.referenced_object_id
--LEFT JOIN   sys.tables              tfk ON fk.parent_object_id      =  tfk.object_id
--LEFT JOIN   sys.schemas             sfk ON tfk.schema_id            =  sfk.schema_id
--LEFT JOIN   sys.columns             cfk ON tfk.object_id            =  cfk.object_id AND cfk.column_id = referenced_column_id
--WHERE       c.object_id = object_id('dbo' + '.' + 'ClassRoom') AND c.is_identity = 1
--ORDER BY    c.column_id
DECLARE @TableNameUpMain    NVARCHAR (60) = @TableName,
        @SchemaNameUpMain   NVARCHAR (60) = @SchemaName,
        @ColumnUpMain       NVARCHAR (60) = '',
        @fkTableUp          VARCHAR(MAX)  = '',
        @fkColumnUp         VARCHAR(MAX)  = '',
        @fkSchemaNameUp     VARCHAR(60)   = '',
        @NumberTablesUp     INT           = 2,
        @TableJoinNamesUp   NVARCHAR(MAX) = '',                
        @ColumnsJoinUp      VARCHAR(MAX)  = ''

DECLARE TablesJoinUp_Cursor CURSOR READ_ONLY
FOR
SELECT      c.name, tfk.name, cfk.name, sfk.name
FROM        sys.all_columns         c
LEFT JOIN   sys.foreign_key_columns fk  ON c.object_id              =  fk.referenced_object_id
LEFT JOIN   sys.tables              tfk ON fk.parent_object_id      =  tfk.object_id
LEFT JOIN   sys.schemas             sfk ON tfk.schema_id            =  sfk.schema_id
LEFT JOIN   sys.columns             cfk ON tfk.object_id            =  cfk.object_id AND cfk.column_id = referenced_column_id
WHERE       c.object_id = object_id(@SchemaNameDownMain + '.' + @TableNameDownMain) AND c.is_identity = 1
ORDER BY    c.column_id

OPEN TablesJoinUp_Cursor
FETCH NEXT FROM TablesJoinUp_Cursor INTO @ColumnUpMain, @fkTableUp, @fkColumnUp, @fkSchemaNameUp
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @ColumnJoinNameUp        VARCHAR(MAX)  = ''           
                   
    SET @TableJoinNamesUp = @TableJoinNamesUp + 'INNER JOIN [' + @fkSchemaNameUp +'].[' + @fkTableUp + '] ' + CHAR(64 + @NumberTablesUp) + ' WITH (NOLOCK) ON A.' + @ColumnUpMain + ' = ' + CHAR(64 + @NumberTablesUp) + '.' + @fkColumnUp + CHAR(13)
                                                 
    DECLARE ColumnsJoin_Cursor CURSOR READ_ONLY
    FOR
    SELECT      c.name
    FROM        sys.all_columns         c 
    INNER JOIN  sys.types               ty  ON c.system_type_id = ty.system_type_id
    LEFT JOIN   sys.foreign_key_columns fk  ON c.object_id = fk.parent_object_id AND c.column_id = fk.parent_column_id
    LEFT JOIN   sys.tables              tfk ON fk.referenced_object_id = tfk.object_id
    LEFT JOIN   sys.columns             cfk ON tfk.object_id = cfk.object_id AND cfk.column_id = referenced_column_id
    WHERE c.object_id = object_id(@fkSchemaNameUp + '.' + @fkTableUp)
    AND ty.name NOT IN ('sysname')
    ORDER BY c.column_id

    OPEN ColumnsJoin_Cursor
        FETCH NEXT FROM ColumnsJoin_Cursor INTO @ColumnJoinNameUp
        WHILE @@FETCH_STATUS = 0
        BEGIN 
            DECLARE @ColumnJoinAuxUp              NVARCHAR(MAX) = ''
                                
            SET @ColumnJoinAuxUp = CHAR(64 + @NumberTablesUp) + N'.['+ @ColumnJoinNameUp + '], '
            SET @ColumnsJoinUp = @ColumnsJoinUp + @ColumnJoinAuxUp
                                                                                                      
            FETCH NEXT FROM ColumnsJoin_Cursor INTO @ColumnJoinNameUp
        END               
        SET @ColumnsJoinUp = @ColumnsJoinUp + CHAR(13)

    CLOSE ColumnsJoin_Cursor
    DEALLOCATE ColumnsJoin_Cursor

    SET @NumberTablesUp = @NumberTablesUp + 1

    FETCH NEXT FROM TablesJoinUp_Cursor INTO @ColumnUpMain, @fkTableUp, @fkColumnUp, @fkSchemaNameUp
    END     
CLOSE TablesJoinUp_Cursor
DEALLOCATE TablesJoinUp_Cursor

PRINT 'USE ' + DB_NAME() + ';
GO
-- Script RollOut
GO
'
IF NOT EXISTS ( SELECT t.name AS TableName FROM sys.tables t INNER JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE t.type = 'U' AND t.name = 'Log_' + @TableName AND s.name = @SchemaName )
BEGIN
PRINT 'CREATE TABLE [' + @SchemaName + '].[Log_' + @TableName + '] ( ' + CHAR(13) + CHAR(9) +
'[Operation]               VARCHAR (25) NOT NULL,' + CHAR(13) + CHAR(9) +
REPLACE(REPLACE(@ColumnPKParameterType, '@', '['), ' ', '] ') + ' NOT NULL,'  + CHAR(13) +
--stuff(REPLACE(@ColumnsParameterType, '@', '['), charindex(' ', REPLACE(@ColumnsParameterType, '@', '[')), len(' '), ']') + CHAR(13) +--REPLACE(REPLACE(REPLACE(@ColumnsParameterType, '@', '['), ' ', '] '),',',' ') + CHAR(13) + CHAR(9) +
@ColumnTypeRequired + CHAR(9) +
'[ModifiedBy]              VARCHAR (128)      NOT NULL,' + CHAR(13) + CHAR(9) +
'[ModifiedDateTime]        DATETIMEOFFSET (7) NOT NULL,' + CHAR(9) + '
CONSTRAINT [PK_Log_' + @TableName + '] PRIMARY KEY CLUSTERED ([Operation] ASC, ' + @ColumnPK + ' ASC, [ModifiedDateTime] ASC)' + CHAR(13) + ')
GO
'
SET @SqlRBTable = 'DROP TABLE [' + @SchemaName + '].[Log_' + @TableName + '];
GO
'
END
ELSE
BEGIN
  DECLARE @ColumnNameD        NVARCHAR (60)  = '', 
          @DataTypeD          NVARCHAR (60)  = '', 
          @ColumnLenD         NVARCHAR (60)  = '', 
          @ScaleD             NVARCHAR (60)  = '',
          @ColumNamesD        NVARCHAR (MAX) = ''

  DECLARE cd_Cursor CURSOR FAST_FORWARD
  FOR
  SELECT     c.name, dt.name, c.max_length, c.scale
  FROM       sys.tables       t
  INNER JOIN sys.all_columns  c  ON t.object_id = c.object_id
  INNER JOIN sys.types        dt ON dt.system_type_id = c.system_type_id
  WHERE      t.type = 'U' AND t.name = @TableName AND SCHEMA_NAME(t.schema_id) = @SchemaName
  GROUP BY   c.name, dt.name, c.max_length, c.scale
  EXCEPT
  SELECT     c.name, dt.name, c.max_length, c.scale
  FROM       sys.tables       t
  INNER JOIN sys.all_columns  c  ON t.object_id = c.object_id
  INNER JOIN sys.types        dt ON dt.system_type_id = c.system_type_id
  WHERE      t.type = 'U' AND t.name = 'Log_' + @TableName AND SCHEMA_NAME(t.schema_id) = @SchemaName
  
  OPEN cd_Cursor
      FETCH NEXT FROM cd_Cursor INTO @ColumnNameD, @DataTypeD, @ColumnLenD, @ScaleD
          WHILE @@FETCH_STATUS = 0
          BEGIN
               SET @ColumNamesD = @ColumNamesD + ('[' + @ColumnNameD + '] ' + @DataTypeD) + ',' + CHAR(13)                        
         FETCH NEXT FROM cd_Cursor INTO @ColumnNameD, @DataTypeD, @ColumnLenD, @ScaleD
      END
  CLOSE cd_Cursor
  DEALLOCATE cd_Cursor    
  
  IF ( @ColumNamesD != '' )
  BEGIN
  PRINT 'ALTER TABLE [' + @SchemaName + '].[Log_' + @TableName + ']
    ADD ' + LEFT(@ColumNamesD, LEN(@ColumNamesD)-2) + '
GO
'
SET @SqlRBTable = 'ALTER TABLE [' + @SchemaName + '].[Log_' + @TableName + ']
    DROP COLUM ' + LEFT(@ColumNamesD, LEN(@ColumNamesD)-2) + '
GO
'
   END
END

PRINT @ExtendeProperty

IF NOT EXISTS (SELECT c.name
               FROM sys.extended_properties AS ep
               INNER JOIN sys.tables        AS t ON ep.major_id = t.object_id 
               INNER JOIN sys.columns       AS c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
               WHERE t.name = @TableName AND c.name = 'BeginDate' )
BEGIN
   PRINT 'EXECUTE sp_addextendedproperty @name = N''MS_Description'', @value = N''Record has a finite life in the system. This is the time the record is first available as an agent in the system.'', @level0type = N''SCHEMA'', @level0name = N''' + @SchemaName + ''', @level1type = N''TABLE'', @level1name = N''' + @TableName + ''', @level2type = N''COLUMN'', @level2name = N''BeginDate'';
GO
'                    
END 
IF NOT EXISTS (SELECT c.name
               FROM sys.extended_properties AS ep
               INNER JOIN sys.tables        AS t ON ep.major_id = t.object_id 
               INNER JOIN sys.columns       AS c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
               WHERE t.name = @TableName AND   c.name = 'BeginDateTime' )
BEGIN
    PRINT 'EXECUTE sp_addextendedproperty @name = N''MS_Description'', @value = N''Record has a finite life in the system. This is the time the record is first available as an agent in the system. The time is meaningful because settlement of financial transactions is highly time sensative.'', @level0type = N''SCHEMA'', @level0name = N''' + @SchemaName + ''', @level1type = N''TABLE'', @level1name = N''' + @TableName + ''', @level2type = N''COLUMN'', @level2name = N''BeginDateTime'';
GO
'                    
END
IF NOT EXISTS (SELECT c.name
               FROM sys.extended_properties AS ep
               INNER JOIN sys.tables        AS t ON ep.major_id = t.object_id 
               INNER JOIN sys.columns       AS c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
               WHERE t.name = @TableName AND   c.name = 'EndDate' )
BEGIN
    PRINT 'EXECUTE sp_addextendedproperty @name = N''MS_Description'', @value = N''Data records in the Master Model are valid for a specific time period. The end date is the last day for which this record is valid.'', @level0type = N''SCHEMA'', @level0name = N''' + @SchemaName + ''', @level1type = N''TABLE'', @level1name = N''' + @TableName + ''', @level2type = N''COLUMN'', @level2name = N''EndDate'';
GO
'                    
END
IF NOT EXISTS (SELECT c.name
               FROM  sys.extended_properties AS ep
               INNER JOIN sys.tables        AS t ON ep.major_id = t.object_id 
               INNER JOIN sys.columns       AS c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
               WHERE t.name = @TableName AND   c.name = 'EndDateTime' )
BEGIN
    PRINT 'EXECUTE sp_addextendedproperty @name = N''MS_Description'', @value = N''Data records in the Master Model are valid for a specific time period. The end date time defines the moment, the time of day for when the record is no longer valid.'', @level0type = N''SCHEMA'', @level0name = N''' + @SchemaName + ''', @level1type = N''TABLE'', @level1name = N''' + @TableName + ''', @level2type = N''COLUMN'', @level2name = N''EndDateTime'';
GO
'                    
END
IF NOT EXISTS (SELECT c.name
               FROM sys.extended_properties AS ep
               INNER JOIN sys.tables        AS t ON ep.major_id = t.object_id 
               INNER JOIN sys.columns       AS c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
               WHERE t.name = @TableName AND   c.name = 'CreatedBy' )
BEGIN
    PRINT 'EXECUTE sp_addextendedproperty @name = N''MS_Description'', @value = N''The user that creates the record.'', @level0type = N''SCHEMA'', @level0name = N''' + @SchemaName + ''', @level1type = N''TABLE'', @level1name = N''' + @TableName + ''', @level2type = N''COLUMN'', @level2name = N''CreatedBy'';
GO
'                    
END                
IF NOT EXISTS (SELECT c.name
               FROM sys.extended_properties AS ep
               INNER JOIN sys.tables        AS t ON ep.major_id = t.object_id 
               INNER JOIN sys.columns       AS c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
               WHERE t.name = @TableName AND   c.name = 'CreatedDate' )
BEGIN
    PRINT 'EXECUTE sp_addextendedproperty @name = N''MS_Description'', @value = N''Each data record in the Master Model bears a Creation Stamp indicating when and by whom it was entered into storage. The Created Date value indicates the date the record was created.'', @level0type = N''SCHEMA'', @level0name = N''' + @SchemaName + ''', @level1type = N''TABLE'', @level1name = N''' + @TableName + ''', @level2type = N''COLUMN'', @level2name = N''CreatedDate'';
GO
'                    
END
IF NOT EXISTS (SELECT c.name
               FROM sys.extended_properties AS ep
               INNER JOIN sys.tables        AS t ON ep.major_id = t.object_id 
               INNER JOIN sys.columns       AS c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
               WHERE t.name = @TableName AND   c.name = 'CreatedDateTime' )
BEGIN
    PRINT 'EXECUTE sp_addextendedproperty @name = N''MS_Description'', @value = N''Each data record in the Master Model bears a Creation Stamp indicating when and by whom it was entered into storage. The Created Date Time value indicates the time the record was created.'', @level0type = N''SCHEMA'', @level0name = N''' + @SchemaName + ''', @level1type = N''TABLE'', @level1name = N''' + @TableName + ''', @level2type = N''COLUMN'', @level2name = N''CreatedDateTime'';
GO
'                    
END

PRINT @SqlHeader + CHAR(13)

PRINT 'CREATE PROCEDURE [' + @SchemaName + '].[usp_' + @TableName + '_Sel] ( ' + CHAR(13) +
@ColumnPKParameterType + ' = 0' + CHAR(13) +')
AS
BEGIN
    SET NOCOUNT ON;

    SET ' + @ColumnPKParameter + ' = ISNULL(' + @ColumnPKParameter + ', 0)

    IF ( ' + @ColumnPKParameter + ' = 0 )
    BEGIN
         SELECT ' + @ColumnPK + ', ' + @ColumnsBracket + '
         FROM   [' + @SchemaName + '].[' + @TableName + '] WITH (NOLOCK)
         WHERE  EndDate IS NULL
    END
    ELSE
    BEGIN
         SELECT ' + @ColumnPK + ', ' + @ColumnsBracket + '
         FROM   [' + @SchemaName + '].[' + @TableName + '] WITH (NOLOCK)
         WHERE  ' +  @ColumnPK + ' = ' + @ColumnPKParameter + '
         AND    EndDate IS NULL
    END

    SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON OBJECT::[' + @SchemaName + '].[usp_' + @TableName + '_Sel] TO [PagosAnticipados];
GO
'

SET @SqlRBspGet = 'DROP PROCEDURE [' + @SchemaName + '].[usp_' + @TableName + '_Sel];
GO
'
-- Inner Join Down
IF ( @ColumnsJoinDown != '' )
BEGIN
PRINT 'SELECT ' + REPLACE(@ColumnPK, '[', 'A.[') + ', ' + REPLACE(@ColumnsBracket, '[', 'A.[') + ', ' + CHAR(13) + LEFT(@ColumnsJoinDown, LEN(@ColumnsJoinDown)-3) + CHAR(13) + 'FROM       [' + @SchemaName + '].[' + @TableName + '] A WITH (NOLOCK)
' + @TableJoinNamesDown + 'WHERE  A.' +  @ColumnPK + ' = ' + @ColumnPKParameter + '
AND    A.EndDate IS NULL
GO
'

PRINT 'SELECT     *'+ CHAR(13) + 'FROM       [' + @SchemaName + '].[' + @TableName + '] A WITH (NOLOCK)
' + @TableJoinNamesDown + 'WHERE  A.' +  @ColumnPK + ' = ' + @ColumnPKParameter + '
AND    A.EndDate IS NULL
GO
'
END

-- Inner Join Up
IF ( @ColumnsJoinUp != '' )
BEGIN
PRINT 'SELECT ' + REPLACE(@ColumnPK, '[', 'A.[') + ', ' + REPLACE(@ColumnsBracket, '[', 'A.[') + ', ' + CHAR(13) + LEFT(@ColumnsJoinUp, LEN(@ColumnsJoinUp)-3) + CHAR(13) + 'FROM       [' + @SchemaName + '].[' + @TableName + '] A WITH (NOLOCK)
' + @TableJoinNamesUp + 'WHERE  A.' +  @ColumnPK + ' = ' + @ColumnPKParameter + '
AND    A.EndDate IS NULL
GO
'

PRINT 'SELECT     *'+ CHAR(13) + 'FROM       [' + @SchemaName + '].[' + @TableName + '] A WITH (NOLOCK)
' + @TableJoinNamesUp + 'WHERE  A.' +  @ColumnPK + ' = ' + @ColumnPKParameter + '
AND    A.EndDate IS NULL
GO
'
END

SET @SqlspGet = 'CREATE PROCEDURE [' + @SchemaName + '].[usp_' + @TableName + '_Load] (' + CHAR(13) +
@ColumnPKParameterType + ' = 0 OUTPUT,' + CHAR(13) +
@ColumnsParameterType + '
)
AS
BEGIN
    SET NOCOUNT ON;' + CHAR(13) + '
        SET ' + @ColumnPKParameter + ' = ISNULL(' + @ColumnPKParameter + ', 0)' + CHAR(13) + '
        BEGIN TRY' + CHAR(13) + '
        BEGIN TRANSACTION Tran' + @TableName + CHAR(13) + '
        IF ( ' + @ColumnPKParameter + ' > 0 )
        BEGIN
            UPDATE [' + @SchemaName + '].[' + @TableName + ']
            SET    ' + @ColumnsFusion + '
            WHERE  ' + @ColumnPK + ' = ' + @ColumnPKParameter + '
        END

        IF ( ' + @ColumnPKParameter + ' = 0 )
        BEGIN
           INSERT INTO [' + @SchemaName + '].[' + @TableName + '] (' + @ColumnsBracket + ')
           VALUES (' + @ColumnsParameter + ')

           SET ' + @ColumnPKParameter + ' = @@IDENTITY;' + CHAR(13) + '
        END' + CHAR(13) + '
        
        COMMIT TRANSACTION Tran' + @TableName + CHAR(13) + '
        END TRY' + CHAR(13) + '
        BEGIN CATCH
                IF (@@TRANCOUNT > 0)
                BEGIN
                    ROLLBACK TRANSACTION Tran' + @TableName + '
                END
                
                SELECT ERROR_NUMBER()    AS NumError
                      ,ERROR_SEVERITY()  AS Severidad
                      ,ERROR_STATE()     AS Estado
                      ,ERROR_PROCEDURE() AS Procedimiento
                      ,CASE
                         WHEN @@TRANCOUNT > 0 THEN N''Se ha cancelado la transacción en curso.''
                         ELSE N''No existían transacciones en curso.''
                       END               AS EstadoTransaccion
                      ,ERROR_LINE()      AS Linea
                      ,ERROR_MESSAGE()   AS Mensaje
        END CATCH

        SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON OBJECT::[' + @SchemaName + '].[usp_' + @TableName + '_Load] TO [PagosAnticipados];
GO
'

SET @SqlRBspLoad = 'DROP PROCEDURE [' + @SchemaName + '].[usp_' + @TableName + '_Load];
GO
'

PRINT @SqlHeader + CHAR(13)
PRINT @SqlspGet

--Delete trigger
IF EXISTS( SELECT tr.name FROM sys.tables t INNER JOIN sys.triggers tr on t.object_id = tr.parent_id WHERE t.type = 'U' and t.name = @tablename and tr.name = @tablename + '_DELETE_TR' )
BEGIN
   SET @sqlTriggerAction = 'ALTER '
   SELECT @SqlRBTriggerDelete = REPLACE(DEFINITION, 'CREATE ',@sqlTriggerAction) FROM sys.sql_modules WHERE object_id = object_id('[' + @SchemaName + '].['+ @tablename +'_DELETE_TR]')
END
ELSE 
BEGIN
   SET @sqlTriggerAction = 'CREATE '
   SET @SqlRBTriggerDelete = 'DROP TRIGGER ' + '[' + @SchemaName + '].['+ @tablename +'_DELETE_TR]'
END

SET @SqlTriggerDelete = @sqlTriggerAction + 'TRIGGER [' + @SchemaName + '].['+ @tablename +'_DELETE_TR] ON [' + @SchemaName + '].['+ @tablename +'] AFTER DELETE
AS
BEGIN
   SET NOCOUNT ON;' + CHAR(13) + '   
   INSERT INTO [' + @SchemaName + '].[Log_'+ @tablename + '] ([Operation], ' + @ColumnPK + ', ' + @ColumnsBracket + ', [ModifiedBy], [ModifiedDateTime])
   SELECT ''DELETE'''+ ', ' + @ColumnPK + ', ' + @ColumnsBracket + ', SYSTEM_USER, GETDATE()
   FROM DELETED ' + CHAR (13) + '
   SET NOCOUNT OFF;
END
GO
'

--PRINT @SqlHeader + CHAR(13)
--PRINT @SqlTriggerDelete

--Update trigger
IF EXISTS( SELECT tr.name FROM sys.tables t inner join sys.triggers tr on t.object_id = tr.parent_id WHERE t.type = 'U' and t.name = @tablename and tr.name =  @tablename + '_UPDATE_TR' )
BEGIN  
   SET @sqlTriggerAction = 'ALTER ' 
   SELECT @SqlRBTriggerUpdate = REPLACE(DEFINITION, 'CREATE ',@sqlTriggerAction) FROM sys.sql_modules WHERE object_id = object_id('[' + @SchemaName + '].['+ @tablename +'_UPDATE_TR]')
END
ELSE 
BEGIN  
   SET @sqlTriggerAction = 'CREATE ' 
   SET @SqlRBTriggerUpdate = 'DROP TRIGGER ' + '[' + @SchemaName + '].['+ @tablename +'_UPDATE_TR]'
END

SET @SqlTriggerUpdate = @sqlTriggerAction + 'TRIGGER [' + @SchemaName + '].['+ @tablename +'_UPDATE_TR] ON [' + @SchemaName + '].[' + @tablename + '] AFTER UPDATE
AS
BEGIN
   SET NOCOUNT ON;' + CHAR(13) + '
   INSERT INTO [' + @SchemaName + '].[Log_'+ @tablename + '] ([Operation], ' + @ColumnPK + ', ' + @ColumnsBracket + ', [ModifiedBy], [ModifiedDateTime])
   SELECT ''UPDATE - Pre'''+ ', ' + @ColumnPK + ', ' + @ColumnsBracket + ', SYSTEM_USER, GETDATE()
   FROM DELETED
   EXCEPT
   SELECT ''UPDATE - Pre'''+ ', ' + @ColumnPK + ', ' + @ColumnsBracket + ', SYSTEM_USER, GETDATE()
   FROM INSERTED ' + CHAR(13) + '
   IF @@ROWCOUNT >= 1 BEGIN
      INSERT INTO [' + @SchemaName + '].[Log_'+ @tablename + '] ([Operation], ' + @ColumnPK + ', ' + @ColumnsBracket + ', [ModifiedBy], [ModifiedDateTime])
      SELECT ''UPDATE - Post'''+ ', ' + @ColumnPK + ', ' + @ColumnsBracket + ', SYSTEM_USER, GETDATE()
      FROM INSERTED
   END' + CHAR(13) + '
   SET NOCOUNT OFF;
END
GO
'

--PRINT @SqlHeader + CHAR(13)
--PRINT @SqlTriggerUpdate

--Insert trigger
IF EXISTS( SELECT tr.name FROM sys.tables t inner join sys.triggers tr on t.object_id = tr.parent_id WHERE t.type = 'U' and t.name = @tablename and tr.name =  @tablename + '_INSERT_TR' )
BEGIN
   SET @sqlTriggerAction = 'ALTER '
   SELECT @SqlRBTriggerInsert = REPLACE(DEFINITION, 'CREATE ',@sqlTriggerAction) FROM sys.sql_modules WHERE object_id = object_id('[' + @SchemaName + '].['+ @tablename +'_INSERT_TR]')
END
ELSE 
BEGIN
   SET @sqlTriggerAction = 'CREATE '
   SET @SqlRBTriggerInsert = 'DROP TRIGGER ' + '[' + @SchemaName + '].['+ @tablename +'_INSERT_TR]'
END

SET @SqlTriggerInsert =        @sqlTriggerAction + 'TRIGGER [' + @SchemaName + '].['+ @tablename + '_INSERT_TR] ON [' + @SchemaName + '].['+ @tablename +'] AFTER INSERT
AS
BEGIN
   SET NOCOUNT ON;' + CHAR(13) + '
   INSERT INTO [' + @SchemaName + '].[Log_'+ @tablename + '] ([Operation], ' + @ColumnPK + ', ' + @ColumnsBracket + ', [ModifiedBy], [ModifiedDateTime])
   SELECT ''INSERT'''+ ', ' + @ColumnPK + ', ' + @ColumnsBracket + ', SYSTEM_USER, GETDATE()
   FROM INSERTED ' + CHAR(13) + '
   SET NOCOUNT OFF;
END
GO
'

PRINT @SqlHeader + CHAR(13)
PRINT @SqlTriggerInsert

PRINT CHAR(13) + CHAR(13) + '/**********************************************************************************************************************************************************************/' + CHAR(13) + CHAR(13)

PRINT 'USE ' + DB_NAME() + '
GO'
PRINT '-- RollBack'
PRINT @SqlRBTable
PRINT @SqlRBspGet
PRINT @SqlRBspLoad
PRINT @SqlRBTriggerDelete + '
GO
'
PRINT @SqlRBTriggerUpdate + '
GO
'
PRINT @SqlRBTriggerInsert + '
GO
'

PRINT CHAR(13) + CHAR(13) + '/**********************************************************************************************************************************************************************/' + CHAR(13) + CHAR(13)

PRINT '-- Test' + CHAR(13)

DECLARE --@TableName     NVARCHAR (60)  =  'TestH',@SchemaName    NVARCHAR (10)  =  'dbo',@NumberCol     INT            =  0,
        @TableCount    INT            =  0,
        @TableNameB    sysname        =  '',
        @ColPKB        VARCHAR (MAX)  =  '',
        @AllColumns    VARCHAR (MAX)  =  ''

DECLARE CTables CURSOR READ_ONLY
FOR 
SELECT     t.name AS TableName, COUNT(c.column_id), s.name AS SchemaName
FROM       sys.tables       t
INNER JOIN sys.schemas      s  ON t.schema_id = s.schema_id
INNER JOIN sys.all_columns  c  ON t.object_id = c.object_id
WHERE      t.type = 'U' 
AND        t.name NOT LIKE 'Log_%'
AND        t.name = @TableName--AND s.name NOT IN ('Mappings')--AND t.name NOT IN ('__RefactorLog', 'sysdiagrams')
GROUP BY   t.name, s.name
      
OPEN CTables
FETCH NEXT FROM CTables INTO @TableName, @NumberCol, @SchemaName
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @SqlInsertT      VARCHAR(MAX)  = '',
            @SqlUpdateT      VARCHAR(MAX)  = '',
            @SqlDeleteT      VARCHAR(MAX)  = '',
            @ColumnNameT     VARCHAR(MAX)  = '',
            @DataTypeT       NVARCHAR(20)  = '',
            @ColumnLenT      NVARCHAR(8)   = '',
            @isIdentityT     BIT           = 0,
            @fkTableT        VARCHAR(MAX)  = '',
            @fkColumnT       VARCHAR(MAX)  = '',           
            @ColCountT       INT           = 1,
            @ColumnsT        VARCHAR(MAX)  = '',
            @ColumnsTValueT  VARCHAR(MAX)  = '',
            @ColumnPKT       NVARCHAR(60)  = '',
            @ParameterValueT VARCHAR(MAX)  = ''

    DECLARE CColumns CURSOR READ_ONLY
    FOR
        SELECT      c.name, ty.name AS dataType, c.max_length, c.is_identity, tfk.name, cfk.name--, * 
        FROM        sys.all_columns         c 
        INNER JOIN  sys.types               ty  ON c.system_type_id = ty.system_type_id
        LEFT JOIN   sys.foreign_key_columns fk  ON c.object_id = fk.parent_object_id AND c.column_id = fk.parent_column_id
        LEFT JOIN   sys.tables              tfk ON fk.referenced_object_id = tfk.object_id
        LEFT JOIN   sys.columns             cfk ON tfk.object_id = cfk.object_id AND cfk.column_id = referenced_column_id
        WHERE c.object_id = object_id(@TableName)--('AccountAddress')
        AND ty.name NOT IN ('sysname')
        ORDER BY c.column_id

        OPEN CColumns
        FETCH NEXT FROM CColumns INTO @ColumnNameT, @DataTypeT, @ColumnLenT, @isIdentityT, @fkTableT, @fkColumnT
        WHILE @@FETCH_STATUS = 0
        BEGIN 
            DECLARE @ColumnAuxT         NVARCHAR(MAX)  = '',        
                    @ColumnsTValueTAux  NVARCHAR(MAX)  = '',
                    @sqlStatementT      NVARCHAR(MAX)  = '',
                    @fkIDT              VARCHAR(25)    = '',
                    @ParameterValueAuxT NVARCHAR(MAX)  = ''

            IF ( @isIdentityT = 1 )
            BEGIN 
                SET @ColumnPKT = N'[' + @ColumnNameT + N']';
            END
                  
            IF ( @ColumnPKT = N'' AND @ColCountT = 1 )
            BEGIN
                SET @ColumnPKT = N'[' + @ColumnNameT + N']';
            END                
                                  
            IF ( @ColCountT < @NumberCol )
            BEGIN                                  
                IF ( @isIdentityT = 0 )
                BEGIN
                SET @ColumnAuxT = N'['+ @ColumnNameT + '], ' --+ CHAR(13)

                IF ( @DataTypeT IN ('INT', 'BIT', 'FLOAT', 'NUMERIC', 'SMALLINT', 'TINYINT', 'BIGINT') )
                BEGIN
                    IF ( @fkTableT <> '' AND @fkColumnT <> '' ) 
                    BEGIN      
                        SET @sqlStatementT = N'SELECT TOP 1 @fkIDTOUT = [' + @fkColumnT + '] FROM [' + @fkTableT + '] WITH (NOLOCK)'                                       
                                                        --PRINT @sqlStatementT
                        EXECUTE sp_executesql @sqlStatementT, N'@fkIDTOUT VARCHAR(25) OUTPUT', @fkIDTOUT = @fkIDT OUTPUT                                       
                        SET @ColumnsTValueTAux =  CASE WHEN @fkIDT = N'' THEN '1' ELSE @fkIDT END + N', '
                    END                          
                    ELSE
                    BEGIN                                                    
                        SET @ColumnsTValueTAux = N'1, '
                    END
                END
                         
                IF ( @DataTypeT IN ('DECIMAL', 'CURRENCY', 'MONEY') )
                BEGIN 
                SET @ColumnsTValueTAux = N'''1'', '
                END                       
  
                IF (@DataTypeT IN ('VARCHAR', 'NVARCHAR', 'CHAR', 'NCHAR', 'TEXT') )  
                BEGIN 
                    IF ( @fkTableT <> '' AND @fkColumnT <> '' ) 
                    BEGIN      
                        SET @sqlStatementT = N'SELECT TOP 1 @fkIDTOUT = [' + @fkColumnT + '] FROM [' + @fkTableT + '] WITH (NOLOCK)'
                                                        --PRINT @sqlStatementT
                        EXECUTE sp_executesql @sqlStatementT, N'@fkIDTOUT VARCHAR(25) OUTPUT', @fkIDTOUT = @fkIDT OUTPUT                                    
                                                        --PRINT @ColumnLenT   
                        SET @ColumnsTValueTAux =  CASE WHEN @fkIDT = N'' THEN N'''Test'', ' ELSE '''' + @fkIDT + '''' END + N', '
                    END                          
                    ELSE
                    BEGIN
                        IF (@ColumnLenT IN (1, 2, 3))                    
                            SET @ColumnsTValueTAux = N'''P'', '
                        ELSE
                            SET @ColumnsTValueTAux = N'''Test'', '
                    END
                END

            IF (@DataTypeT IN ('DATE', 'DATETIME', 'DATETIME2', 'DATETIMEOFFSET', 'SMALLDATETIME', 'TIME') )  
            BEGIN 
            SET @ColumnsTValueTAux = N'GETDATE(), '
            END
  
            IF (@DataTypeT IN ('VARBINARY') )  
            BEGIN 
                SET @ColumnsTValueTAux = N'CAST(''TEST'' AS VARBINARY(MAX)), '
            END
  
            IF (@DataTypeT IN ('UNIQUEIDENTIFIER') )  
            BEGIN 
                SET @ColumnsTValueTAux = N'NEWID(), '
            END                             
                            END                                               
                            END
                            ELSE
            BEGIN                
                SET @ColumnAuxT = N'['+ @ColumnNameT + ']'
                IF (@DataTypeT IN ('INT', 'BIT', 'FLOAT', 'NUMERIC', 'SMALLINT', 'TINYINT', 'BIGINT') )                                                                     
                BEGIN 
                    IF ( @fkTableT <> '' AND @fkColumnT <> '' ) 
                    BEGIN      
                        SET @sqlStatementT = N'SELECT TOP 1 @fkIDTOUT = [' + @fkColumnT + '] FROM [' + @fkTableT + '] WITH (NOLOCK)'                                       
                        --PRINT @sqlStatementT
                        EXECUTE sp_executesql @sqlStatementT, N'@fkIDTOUT VARCHAR(25) OUTPUT', @fkIDTOUT = @fkIDT OUTPUT                                       
                       SET @ColumnsTValueTAux =  CASE WHEN @fkIDT = N'' THEN '1' ELSE @fkIDT END + N''
                    END                          
                    ELSE
                    BEGIN                                                    
                        SET @ColumnsTValueTAux = N'1'
                    END
                END

                IF (@DataTypeT IN ('VARCHAR', 'NVARCHAR', 'CHAR', 'NCHAR', 'TEXT') )  
                BEGIN
                    SET @ColumnsTValueTAux = N'''Test'''
                END

                IF ( @DataTypeT IN ('DECIMAL', 'CURRENCY', 'MONEY') )
                BEGIN 
                    SET @ColumnsTValueTAux = N'''1'''
                END

                IF (@DataTypeT IN ('DATE', 'DATETIMEOFFSET', 'DATETIME', 'DATETIME2', 'SMALLDATETIME', 'TIME') )  
                BEGIN 
                    SET @ColumnsTValueTAux = N'GETDATE()'
                END
                         
                IF (@DataTypeT IN ('VARBINARY') )  
                BEGIN 
                    SET @ColumnsTValueTAux = N'CAST(''TEST'' AS VARBINARY(MAX))'
                END
                         
                IF (@DataTypeT IN ('UNIQUEIDENTIFIER') )  
                BEGIN 
                    SET @ColumnsTValueTAux = N'NEWID()'
                END                          
            END
                                  
            IF (@ColCountT > 1)
            BEGIN
            SET @ParameterValueAuxT = CHAR(13) + CHAR(9) +'@'+ @ColumnNameT + ' = ' + @ColumnsTValueTAux
            --PRINT @ColumnAuxT
            END
            SET @ParameterValueT = @ParameterValueT + @ParameterValueAuxT
                                  
            --PRINT @ParameterValueT
                                                            
            SET @ColumnsT = @ColumnsT + @ColumnAuxT        
            SET @ColumnsTValueT = @ColumnsTValueT + @ColumnsTValueTAux
            SET @ColCountT = @ColCountT + 1
                       
            FETCH NEXT FROM CColumns INTO @ColumnNameT, @DataTypeT, @ColumnLenT, @isIdentityT, @fkTableT, @fkColumnT
        END
                                        
        CLOSE CColumns
        DEALLOCATE CColumns                           
                              
        SET @SqlInsertT = N'IF NOT EXISTS ( SELECT TOP 1 ' + @ColumnPKT + ' FROM [dbo].[' + @TableName + N'] WHERE [CreatedBy] = ''Test'')
BEGIN
INSERT INTO [dbo].[' + @TableName + N'] (' + @ColumnsT + N')
VALUES(' + @ColumnsTValueT + N')
END
GO
'
                SET @SqlUpdateT = N'        
UPDATE [dbo].[' + @TableName + N']
SET [CreatedBy] = ''Test1''
WHERE  ' + @ColumnPKT + ' = (SELECT TOP 1 ' + @ColumnPKT + ' FROM [dbo].[' + @TableName + N'] WHERE [CreatedBy] = ''Test'')
GO
'
                SET @SqlDeleteT = N'        
DELETE [dbo].[' + @TableName + N']   
WHERE  ' + @ColumnPKT + ' = (SELECT TOP 1 ' + @ColumnPKT + ' FROM [dbo].[' + @TableName + N'] WHERE [CreatedBy] = ''Test1'')
GO


'
    PRINT @SqlInsertT
        PRINT @SqlUpdateT
            PRINT @SqlDeleteT                
                                           
        FETCH NEXT FROM CTables INTO @TableName, @NumberCol, @SchemaName
    END
          CLOSE CTables
          DEALLOCATE CTables

PRINT 'DECLARE ' + REPLACE(REPLACE(@ColumnPKT, '[', '@'), ']', ' INT = 0') + '

EXEC [' + @SchemaName + '].[usp_' + @TableName + '_Load] ' + CHAR(13) +
      CHAR(9) + REPLACE(REPLACE(@ColumnPKT, '[', '@'), ']', ' = ') + REPLACE(REPLACE(@ColumnPKT, '[', '@'), ']', ' OUTPUT,') +
      @ParameterValueT + CHAR(13) + CHAR(13) +

'SELECT * FROM [dbo].[' + @TableName + N'] WITH (NOLOCK) WHERE ' + @ColumnPKT +' = ' + REPLACE(REPLACE(@ColumnPKT, '[', '@'), ']', '')

PRINT '
EXEC [' + @SchemaName + '].[usp_' + @TableName + '_Sel] ' + CHAR(13) + CHAR(9) + REPLACE(REPLACE(@ColumnPKT, '[', '@'), ']', ' = 1') + '
GO' + CHAR(13)

PRINT 'EXEC [' + @SchemaName + '].[usp_' + @TableName + '_Sel] ' + CHAR(13) + CHAR(9) + REPLACE(REPLACE(@ColumnPKT, '[', '@'), ']', ' = ') + REPLACE(REPLACE(@ColumnPKT, '[', '@'), ']', '') + '
GO' + CHAR(13)

--        FETCH NEXT FROM Tables_Cursor INTO @TableName, @NumberCol, @SchemaName
--    END          
--CLOSE Tables_Cursor
--DEALLOCATE Tables_Cursor

END TRY
BEGIN CATCH      
          SELECT ERROR_LINE() AS ErrorLine, ERROR_MESSAGE() AS ErrorMessage, ERROR_SEVERITY() AS ErrorSeverity, ERROR_STATE() AS ErrorState
END CATCH

SET NOCOUNT OFF;
SET XACT_ABORT OFF;