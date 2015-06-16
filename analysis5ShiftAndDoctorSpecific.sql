# Variables for a particula doctor on a particular shift
SET group_concat_max_len=18446744073709547520; # to fix bug in creating temporary tables; value is max permitted (http://dev.mysql.com/doc/refman/5.1/en/server-system-variables.html#sysvar_group_concat_max_len)
SET @numShifts=(
	SELECT COUNT(DISTINCT `shift`) FROM drshift
);
SET @shiftName=(
	SELECT DISTINCT `shift` FROM drshift
	ORDER BY `iddrshift`
	LIMIT 1 OFFSET 0		# Change the OFFSET value if a different shift is desired.
);
SET @numDoctors=(
	SELECT COUNT(`hash`) FROM drshift
	WHERE `shift` = @shiftName
);
SET @doctor=(
	SELECT `hash` FROM drshift WHERE `shift` = @shiftName
	ORDER BY `hash`
	LIMIT 1 OFFSET 0		# Change the OFFSET value if a different doctor is desired for the same shift.
);
SET @shiftstart=(
	SELECT `starttime` FROM wayward.shifts
	WHERE `shiftname` = @shiftName
);
SET @shiftend=(
	SELECT `endtime` FROM wayward.shifts
	WHERE `shiftname` = @shiftName
);
SET @doctorIMEI=(
	SELECT phones.phone_imei AS 'imei'
	FROM wayward.drshift LEFT JOIN phones ON  drshift.`tattooNo` = phones.`phone_name`
	WHERE `hash`= @doctor AND `shift`=@shiftName
);
# Many doctors start working before their official start time and end after their official end time. 
# Here we use an offset of 10800 seconds (3 hours) to account for the discrepancies.
SET @shiftOffset=10800;	

/*
1. In the first phase we take a set of WiFi visibility observations
made at evenly spaced epochs over the course of a shift. For
each of the epochs we obtain a set of visible access points W1
to Wn. 
*/
#Note that the following gives all the macs seen per minute by a particular phone. These are put into a temporary table for subsequent usage.
DROP TEMPORARY TABLE IF EXISTS accesspointsPerEpoch;
CREATE TEMPORARY TABLE accesspointsPerEpoch AS  ( 
	SELECT DISTINCT `time`, FROM_UNIXTIME(`time`,'%W %d %M %Y') AS rdate, FROM_UNIXTIME(`time`,'%H:%i') AS rtime, count(DISTINCT ap_id) as numapids, GROUP_CONCAT(DISTINCT ap_id ORDER BY ap_id) as apids
	FROM scans
	WHERE `time` >= (@shiftstart - @shiftOffset) AND `time` <= (@shiftend + @shiftOffset)
	AND `imei` =  @doctorIMEI
	GROUP BY rtime
	ORDER BY `time`
);
#660 row(s)
#660 row(s) returned	0.562 sec / 0.000 sec


/*
2. For each epoch we turn to the HAN data and obtain a
list of possible task locations. We assume that the ward (place)
associated with the task must be visited for some period after
the task accept time and before the task complete time. 
*/

DROP TABLE IF EXISTS possibleLocs;
CREATE TABLE possibleLocs AS  (
	SELECT DISTINCT @doctor, @doctorIMEI, `time`, rdate, rtime, numapids,
	count(DISTINCT han.`ward`) as numwards, GROUP_CONCAT(DISTINCT han.`ward` ORDER BY  han.`ward`) AS wards, apids
	FROM accesspointsPerEpoch
	RIGHT JOIN han
		ON `timeof_accept` <= time AND `timeof_complete` > time	+ 59	# 59 is used here because we are interested in completions within a minute from the given second
		AND name=@doctor
	GROUP BY rtime
	ORDER BY `time`
);
# 599 row(s) returned	0.109 sec / 0.000 sec

/*
Given a large dataset we expect access points to appear more often
when their associated place is on the task list than we would
if they appeared randomly.
*/

/*
NPW is the number of times an access point W is
observed during a task in place P
*/

# possibleLocs is then parsed by Python script accessPointWardObsCount.py and generates table wayward.macWardObs;