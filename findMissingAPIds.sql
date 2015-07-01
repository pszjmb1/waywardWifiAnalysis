# Fills in some apGroupIds missing from possibleLocs after analysis6AllDoc... has run. 
# Took 401.578 sec with 14426 rows


DROP PROCEDURE IF exists findMissingAPIds;
delimiter #
CREATE PROCEDURE findMissingAPIds()
BEGIN
	DECLARE doctor1 VARCHAR(45) default 0;
	DECLARE aTime INT unsigned default 0;
	DECLARE numMissingRows INT unsigned default (
		SELECT COUNT(*) FROM wayward.possiblelocs WHERE apGroupId IS NULL
	);
	DECLARE groupId longtext default NULL;
	DECLARE v_counterMissingRows INT unsigned default 0;

    START TRANSACTION;
    WHILE v_counterMissingRows < numMissingRows do
		SET doctor1 = (SELECT `doctor` FROM wayward.possiblelocs WHERE apGroupId IS NULL LIMIT 1 OFFSET v_counterMissingRows);
		SET aTime = (SELECT `time` FROM wayward.possiblelocs WHERE apGroupId IS NULL LIMIT 1 OFFSET v_counterMissingRows);
		SET groupId = (SELECT apGroupId FROM wayward.possiblelocs WHERE apids = 
			(SELECT apids FROM wayward.possiblelocs WHERE `doctor` = doctor1 AND `time` = aTime)
			AND apGroupId IS NOT NULL LIMIT 1);
		-- SELECT v_counterMissingRows, doctor1, aTime, groupId;
		SET SQL_SAFE_UPDATES = 0;
			UPDATE possiblelocs
			SET apGroupId=groupId	
			WHERE `doctor`=doctor1 AND `time`=aTime;
		SET SQL_SAFE_UPDATES = 1;

		-- SELECT v_counterMissingRows,numMissingRows-v_counterMissingRows,doctor1,aTime,groupId
		-- INTO OUTFILE 'C:\\Windows\\Temp\\jmbout.txt';
		SET v_counterMissingRows=v_counterMissingRows+1;
	END WHILE;
	COMMIT;
END #

delimiter ;

call findMissingAPIds();