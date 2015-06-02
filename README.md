Wayward Wifi Analysis
=====================

Repository Purpose
------------------
Routines for analysing Wifi scan and job data. This was created during the [Horizon Wayward Project](http://www.horizon.ac.uk/Current-Projects/wayward).

The goal of this analysis is to better inform what doctors are doing on their shifts by combining imprecise job tasking data with Wifi access points that they recorded on their phones during said shifts. 

Usage Instructions
------------------
### Setup
This analysis works with SQL data in the following format:

#### Wifi scans table
##### Description
Many hospitals, especially those with wireless working systems, have high densities of WiFi access points in order to provide robust network connections throughout a site. Consequently, the use of WiFi signal strength captured by a wireless device (such as a mobile phone) has the potential to produce a positioning solution which is accurate to room level. For more information see [1].

Here, WiFi is recorded by giving staff smart phones with access point recording software. Each row records a mac address observed at the given time.

[[1] Brown, M., Pinchin, J., Blum, J., Sharples, S., Shaw, D., Housley, G., ... & Blakey, J. (2014). Exploring the Relationship between Location and Behaviour in Out of Hours Hospital Care. In HCI International 2014-Posters’ Extended Abstracts (pp. 395-400). Springer International Publishing.](http://link.springer.com/chapter/10.1007/978-3-319-07854-0_69)

##### SQL create script
```SQL
CREATE TABLE IF NOT EXISTS `SCANS` (
  `time` int(11) NOT NULL, -- unix timestamp of time of observation
  `rssi` int(4) NOT NULL, -- wifi received signal strength indication
  `mac` varchar(17) NOT NULL, --MAC address for an access point “seen” at the given time
  `ap_id` varchar(14) NOT NULL,
  `imei` bigint(15) NOT NULL, -- International Mobile Station Equipment Identity for the smartphone running
the software. Another table connects the phone to the staff member using it.
  `channel` int(4) NOT NULL, -- Frq in MHz corresponding to a WLan channel
  `ssid` varchar(50) NOT NULL, -- Access point human readable name
  UNIQUE KEY `indx` (`time`,`mac`,`imei`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
```

#### Hospital At Night task table
##### Description
Hospitals with wireless working systems are able to submit jobs to doctors for them to schedule and perform. However, the doctors may keep many jobs in the list at the same time, and there is no requirement for them to makr the jobs as complete within any time frame. Consequently, this data alone is insufficient to determine how long jobs take and their completion order.

##### SQL create script
```SQL
CREATE TABLE `han` (
  `timeof_complete` int(11) NOT NULL,                             -- When the doctor marks the job as complete
  `timeof_submit` int(11) NOT NULL,                               -- When a job is submitted to a doctor
  `timeof_accept` int(11) NOT NULL,                               -- When the doctor has accepted to do the submitted job
  `duration_max_accept` int(3) NOT NULL,
  `duration_min_accept` int(3) NOT NULL,
  `duration_submit` int(3) NOT NULL,
  `priority` int(1) NOT NULL ,                                    -- The importance of a job
  `ward` varchar(20) NOT NULL,                                    -- The hospital ward that the job takes place on 
  `category` varchar(150) NOT NULL,                               -- Category of job
  `close_reason` varchar(50) NOT NULL,                            -- Why the doctor closed the job
  `staff_group` varchar(10) NOT NULL,                             -- Type of doctor performing the job
  `name` varchar(6) NOT NULL,                                     -- Anonymous identifier of the doctor
  `indx` int(11) NOT NULL AUTO_INCREMENT,
  UNIQUE KEY `indx` (`indx`),
  UNIQUE KEY `indx2` (`timeof_submit`,`timeof_complete`,`name`),
  KEY `timeof_submit` (`timeof_submit`),
  KEY `timeof_submit_2` (`timeof_submit`),
  KEY `timeof_submit_3` (`timeof_submit`,`timeof_complete`)
) ENGINE=MyISAM AUTO_INCREMENT=767 DEFAULT CHARSET=utf8;
```
#### Shifts table
##### Description
The shift list of data recordings including shift start and end times.

##### SQL create script
```SQL
CREATE TABLE `shifts` (
  `starttime` int(11) NOT NULL,
  `endtime` int(11) DEFAULT NULL,
  `shiftname` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`starttime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```
#### Dr Shift Table
##### Description
Recording of what shift a doctor was on and what phone (tattooNo) was used to log their Wifi scans.
##### SQL create script
```SQL
CREATE TABLE `drshift` (
  `iddrshift` int(11) NOT NULL AUTO_INCREMENT,
  `hash` varchar(45) DEFAULT NULL,              -- Anonymous identifier of the doctor
  `shift` varchar(45) DEFAULT NULL,             -- Shift name
  `tattooNo` int(11) DEFAULT NULL,              -- phone id
  PRIMARY KEY (`iddrshift`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8;
```
#### Phones Table
##### Description
The list of phones used for Wifi recording
##### SQL create script
```SQL
CREATE TABLE `phones` (
  `phone_name` varchar(45) NOT NULL,            -- phone id
  `phone_imei` varchar(45) NOT NULL,            -- corresponds to scans.imei
  PRIMARY KEY (`phone_imei`),
  UNIQUE KEY `phone_name` (`phone_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```

