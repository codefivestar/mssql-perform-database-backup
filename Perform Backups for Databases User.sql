----------------------------------------------------------------------------------------------------------
-- Author      : Hidequel Puga
-- Date        : 2021-08-07
-- Description : Perform backups for databases user
----------------------------------------------------------------------------------------------------------

--
-- Declarations 
--
DECLARE @default_backup_dir AS NVARCHAR(4000)
	  , @current_date       AS NVARCHAR(25)
	  , @backup_file        AS NVARCHAR(4000)
	  , @backup_set_name    AS  NVARCHAR(150)
	  , @backup_set_id      AS INT
      , @dbname             AS NVARCHAR(50)

DECLARE db_cursor CURSOR FOR SELECT [name] 
                               FROM [master].[dbo].[sysdatabases] 
                              WHERE [name] NOT IN ('master', 'model', 'msdb', 'tempdb')    

	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE'
	                                  , N'Software\Microsoft\MSSQLServer\MSSQLServer'
	                                  , N'BackupDirectory'
	                                  , @default_backup_dir OUTPUT

OPEN db_cursor FETCH NEXT FROM db_cursor INTO @dbname 
 
WHILE @@FETCH_STATUS = 0
    BEGIN

		--
		-- Assignments 
		--
		SET @current_date     = FORMAT(GETDATE(), 'yyyy_MM_dd_HH_mm_tt')
		SET @backup_file      = @default_backup_dir + '\' + @dbname + '_backup_' + @current_date + '.bak'
		SET @backup_set_name  = @dbname + ' - Full Database Backup ' + @current_date

        --
		-- Perform backup
		-- 
		BACKUP DATABASE @dbname 
		  TO DISK = @backup_file WITH NOFORMAT
		, NOINIT
		, NAME    = @backup_set_name
		, SKIP
		, NOREWIND
		, NOUNLOAD
		, COMPRESSION
		, STATS = 10
		, CHECKSUM

		--
		-- Reliability backup
		--
		SELECT @backup_set_id = position 
		  FROM msdb.dbo.backupset 
		 WHERE database_name = @dbname 
		   AND backup_set_id = (
								SELECT MAX(backup_set_id) 
								  FROM msdb..backupset 
								 WHERE database_name = @dbname
								 )

								 SELECT @backup_set_id 

		IF (@backup_set_id IS NULL)
			BEGIN 

				DECLARE @msg_error AS NVARCHAR(MAX)
					SET @msg_error = N'Verify failed. Backup information for database ''' + @dbname + ''' not found.'

				RAISERROR(@msg_error, 16, 1)

			END

		RESTORE VERIFYONLY FROM DISK = @backup_file WITH FILE = @backup_set_id
							  , NOUNLOAD
							  , NOREWIND

		FETCH NEXT FROM db_cursor INTO @dbname

    END
 
CLOSE db_cursor
DEALLOCATE db_cursor