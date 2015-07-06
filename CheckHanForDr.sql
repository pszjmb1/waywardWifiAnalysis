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

SELECT *, FROM_UNIXTIME(`timeof_accept`,'%W %d %M %Y %H:%I:%s') AS rdateAccept , FROM_UNIXTIME(`timeof_complete`,'%W %d %M %Y %H:%I:%s') AS rdateComplete FROM wayward.han
WHERE timeof_accept >= @shiftstart - 14400 AND timeof_complete <= @shiftend + 14400
AND name=@doctor
ORDER BY timeof_accept