# Fills in some apGroupIds missing from possibleLocs after analysis6AllDoc... has run. This version only uses jobs that where the number
# of wards seen during its accept and complete times is 1.

DROP PROCEDURE IF exists findMissingAPIdsV2;
delimiter #
CREATE PROCEDURE findMissingAPIdsV2()
BEGIN
	DECLARE numShifts INT unsigned default (SELECT COUNT(DISTINCT `shift`) FROM drshift);
	DECLARE v_counterShift INT unsigned default 0;
	DECLARE v_counterDoctor INT unsigned default 0;
	DECLARE shiftName1 VARCHAR(45) default 0;
	DECLARE doctor1 VARCHAR(45) default 0;
	DECLARE v_wardJobsForDoctor INT unsigned default 0;
	DECLARE countHan INT unsigned default 0;

    START TRANSACTION;
	WHILE v_counterShift < numShifts do
		SET shiftName1 = ( SELECT DISTINCT `shift` FROM drshift ORDER BY `iddrshift` LIMIT 1 OFFSET v_counterShift );    
		WHILE v_counterDoctor < (SELECT COUNT(`hash`) FROM drshift WHERE `shift` = shiftName1) do
			SET doctor1 = (SELECT `hash` FROM drshift WHERE `shift` = shiftName1 ORDER BY `hash` LIMIT 1 OFFSET v_counterDoctor);
			SET countHan = (SELECT count(*) FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1);
			WHILE countHan > 0 AND v_wardJobsForDoctor < countHan do
				DROP TEMPORARY TABLE IF EXISTS tmp_wardJobsForDocs;
				CREATE TEMPORARY TABLE tmp_wardJobsForDocs
				SELECT shiftName1, doctor1, v_wardJobsForDoctor, `time`, rdate, rtime, wards FROM possiblelocs 
					WHERE doctor=doctor1
					  AND `time` >= (SELECT `starttime` FROM wayward.shifts 	WHERE `shiftname` = shiftName1)
					  AND `time` <= (SELECT `endtime` FROM wayward.shifts WHERE `shiftname` = shiftName1)
					  AND `time` >= (SELECT timeof_accept FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1 AND (timeof_complete-timeof_accept)/60 > 5
					  LIMIT 1 OFFSET v_wardJobsForDoctor)
					  AND `time` <= (SELECT timeof_complete FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1 AND (timeof_complete-timeof_accept)/60 > 5
					  LIMIT 1 OFFSET v_wardJobsForDoctor)
					  AND `numwards` = 1;
				SET @sql_text = CONCAT("SELECT * INTO OUTFILE './/jmb//", DATE_FORMAT( NOW(), '%H_%i_%S'),".txt' FROM tmp_wardJobsForDocs");
				PREPARE s1 FROM @sql_text;
				EXECUTE s1;
				DEALLOCATE PREPARE s1;
				SET v_wardJobsForDoctor=v_wardJobsForDoctor+1;
				SELECT shiftName1, doctor1, v_wardJobsForDoctor, countHan, SLEEP(1.0);
			END WHILE;
			SET v_wardJobsForDoctor = 0;
			SET v_counterDoctor=v_counterDoctor+1;
		END WHILE;
		SET v_counterDoctor = 0;
		SET v_counterShift=v_counterShift+1;
	END WHILE;
	COMMIT;
END #

delimiter ;

call findMissingAPIdsV2();