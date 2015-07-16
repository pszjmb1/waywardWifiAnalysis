# Fills in some apGroupIds missing from possibleLocs after analysis6AllDoc... has run. This version uses jobs that where the number
# of wards seen during its accept and complete times is 1.

DROP PROCEDURE IF exists findMissingAPIdsV2;
delimiter #
CREATE PROCEDURE findMissingAPIdsV2()
BEGIN
	DECLARE numShifts INT unsigned default (SELECT COUNT(DISTINCT `shift`) FROM drshift);
	DECLARE v_counterShift INT unsigned default 0;
	DECLARE v_counterDoctor INT unsigned default 0;
	DECLARE v_counterJobTimes INT unsigned default 0;
	DECLARE shiftName1 VARCHAR(45) default 0;
	DECLARE doctor1 VARCHAR(45) default 0;
	DECLARE v_wardJobsForDoctor INT unsigned default 0;
	DECLARE countHan INT unsigned default 0;
	DECLARE countJobTimes INT unsigned default 0;
	DECLARE jobTime INT unsigned default 0;
	DECLARE v_hanIndx INT unsigned default 0;

    START TRANSACTION;
	
	-- DROP TABLE IF EXISTS wardJobsForDocs;
	-- CREATE TABLE wardJobsForDocs
	-- (shiftName varchar(45), doctor varchar(45), `time` int unsigned, rdate longtext, rtime longtext, wards longtext, hanIndx int unsigned, PRIMARY KEY (doctor,time,hanIndx));
	WHILE v_counterShift < numShifts do
		SET shiftName1 = ( SELECT DISTINCT `shift` FROM drshift ORDER BY `iddrshift` LIMIT 1 OFFSET v_counterShift );    
		WHILE v_counterDoctor < (SELECT COUNT(`hash`) FROM drshift WHERE `shift` = shiftName1) do
			SET doctor1 = (SELECT `hash` FROM drshift WHERE `shift` = shiftName1 ORDER BY `hash` LIMIT 1 OFFSET v_counterDoctor);
			SET countHan = (SELECT count(*) FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1);
			WHILE countHan > 0 AND v_wardJobsForDoctor < countHan do
				SET countJobTimes = (SELECT count(*) FROM possiblelocs
					WHERE doctor=doctor1
					  AND `time` >= (SELECT `starttime` FROM wayward.shifts 	WHERE `shiftname` = shiftName1)
					  AND `time` <= (SELECT `endtime` FROM wayward.shifts WHERE `shiftname` = shiftName1)
					  AND `time` >= (SELECT timeof_accept FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1 AND (timeof_complete-timeof_accept)/60 > 5
					  LIMIT 1 OFFSET v_wardJobsForDoctor)
					  AND `time` <= (SELECT timeof_complete FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1 AND (timeof_complete-timeof_accept)/60 > 5
					  LIMIT 1 OFFSET v_wardJobsForDoctor)
					  AND `numwards` = 1);
				IF countJobTimes > 0 THEN 
					SELECT shiftName1, doctor1, v_wardJobsForDoctor, (SELECT timeof_accept FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1 AND (timeof_complete-timeof_accept)/60 > 5
					  LIMIT 1 OFFSET v_wardJobsForDoctor) AS accept, (SELECT timeof_complete FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1 AND (timeof_complete-timeof_accept)/60 > 5
					  LIMIT 1 OFFSET v_wardJobsForDoctor) AS complete;
					SET v_counterJobTimes = 0;
					WHILE v_counterJobTimes < countJobTimes do
						SET jobTime = (
							SELECT `time` FROM possiblelocs
							WHERE doctor=doctor1
							  AND `time` >= (SELECT `starttime` FROM wayward.shifts 	WHERE `shiftname` = shiftName1)
							  AND `time` <= (SELECT `endtime` FROM wayward.shifts WHERE `shiftname` = shiftName1)
							  AND `time` >= (SELECT timeof_accept FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1 AND (timeof_complete-timeof_accept)/60 > 5
							  LIMIT 1 OFFSET v_wardJobsForDoctor)
							  AND `time` <= (SELECT timeof_complete FROM wayward.han WHERE `close_reason`= 'Completed' AND `name`=doctor1 AND (timeof_complete-timeof_accept)/60 > 5
							  LIMIT 1 OFFSET v_wardJobsForDoctor)
							  AND `numwards` = 1
						    LIMIT 1 OFFSET v_counterJobTimes
						);
						-- SELECT jobTime, shiftName, doctor, `time`, rdate, rtime, wards, (SELECT indx FROM han WHERE `name` = doctor1 AND timeof_accept <= jobTime AND timeof_complete >= jobTime + 60 AND close_reason='Completed'
						-- ) AS hanIndx FROM possiblelocs WHERE `time` = jobTime;
						-- INSERT IGNORE INTO wardJobsForDocs(shiftName, doctor, `time`, rdate, rtime, wards, hanIndx)
						-- SELECT shiftName, doctor, `time`, rdate, rtime, wards, (
						-- 	SELECT indx FROM han WHERE `name` = doctor1 AND timeof_accept <= jobTime AND timeof_complete >= jobTime + 60 AND close_reason='Completed'
						-- ) AS hanIndx FROM possiblelocs 
						-- WHERE `time` = jobTime;
						IF (SELECT COUNT(*) FROM han WHERE `name` = doctor1 AND timeof_accept <= jobTime AND timeof_complete >= jobTime + 60 AND close_reason='Completed') = 1 
						THEN 
							SET v_hanIndx = (SELECT indx FROM han WHERE `name` = doctor1 AND timeof_accept <= jobTime AND timeof_complete >= jobTime + 60 AND close_reason='Completed');
						ELSE
							SET v_hanIndx = 0;
						END IF;
						UPDATE possiblelocs
						SET apGroupId=wards, apGroupIdSimilarity=1, hanIndx=v_hanIndx
						WHERE `doctor`=doctor1 AND `time`=jobTime;
						SET v_counterJobTimes=v_counterJobTimes+1;
					END WHILE;
				END IF;				
				SET v_wardJobsForDoctor=v_wardJobsForDoctor+1;
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