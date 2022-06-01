----------------------------------------------------------------------------------------------------------
-- Author      : Hidequel Puga
-- Date        : 2022-06-01
-- Description : Perform database backup + compress + encryption
----------------------------------------------------------------------------------------------------------

--
-- Declarations 
--
DECLARE @database           AS NVARCHAR(50)
      , @default_backup_dir AS NVARCHAR(4000)
	  , @current_date       AS NVARCHAR(25)
	  , @backup_file        AS NVARCHAR(4000)
	  , @backup_set_name    AS  NVARCHAR(150)
	  , @backup_set_id      AS INT
    
    SET @database     = DB_NAME() -- get current database
	SET @current_date = FORMAT(GETDATE(), 'yyyy_MM_dd_HH_mm_tt') -- date description

    -- get default path for backup (.bak)
	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE'
	                                  , N'Software\Microsoft\MSSQLServer\MSSQLServer'
	                                  , N'BackupDirectory'
	                                  , @default_backup_dir OUTPUT
	SET @backup_file      = @default_backup_dir + '\' + @database + '_backup_' + @current_date + '.bak' -- backup directory + file name .bak
	SET @backup_set_name  = @database + ' - Full Database Backup ' + @current_date -- backup description           

--
-- Perform backup
-- 
BACKUP DATABASE @database 
  TO DISK = @backup_file WITH NOFORMAT
, NOINIT
, NAME    = @backup_set_name
, SKIP
, NOREWIND
, NOUNLOAD
, COMPRESSION
-- encryption
, ENCRYPTION (
		        ALGORITHM          = AES_256
		      , SERVER CERTIFICATE = [CFS_BackupCertificate] -- certificate name
		      )
, STATS = 10
, CHECKSUM

--
-- Reliability backup
--
SELECT @backup_set_id = position 
  FROM msdb.dbo.backupset 
 WHERE database_name = @database 
   AND backup_set_id = (
                        SELECT MAX(backup_set_id) 
                          FROM msdb..backupset 
						 WHERE database_name = @database
						 )

IF (@backup_set_id IS NULL)
	BEGIN 

	    DECLARE @msg_error AS NVARCHAR(MAX)
		    SET @msg_error = N'Verify failed. Backup information for database ''' + @database + ''' not found.'

		RAISERROR(@msg_error, 16, 1)

	END

RESTORE VERIFYONLY FROM  DISK = @backup_file WITH FILE = @backup_set_id
                      , NOUNLOAD
					  , NOREWIND;