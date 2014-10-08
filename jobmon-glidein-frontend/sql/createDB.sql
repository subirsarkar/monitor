CREATE DATABASE monitor;
use monitor;
CREATE TABLE jobinfo_summary
(
   jid        VARCHAR(64) NOT NULL PRIMARY KEY,
   status     CHAR(4)     NOT NULL,
   user       VARCHAR(16) NOT NULL,
   qtime      INT(10)     NOT NULL,
   queue      VARCHAR(16),
   ugroup     VARCHAR(16),
   acct_group VARCHAR(16),
   subject    VARCHAR(256),
   task_id    VARCHAR(256),
   grid_id    VARCHAR(128),
   exec_host  VARCHAR(64),
   rb         VARCHAR(64),
   ceid       VARCHAR(128),
   start      INT(10),
   end        INT(10),
   cputime    MEDIUMINT(7), 
   walltime   MEDIUMINT(7),
   mem        MEDIUMINT,
   vmem       MEDIUMINT,
   diskusage  MEDIUMINT,
   ex_st      MEDIUMINT(7),
   timeleft   MEDIUMINT(7),
   role       VARCHAR(255),
   grid_site  VARCHAR(15),
   jobdesc    VARCHAR(255),
   statusbit  MEDIUMINT(7),
   rank       SMALLINT(6),
   priority   MEDIUMINT(7)
);
describe jobinfo_summary;
CREATE TABLE jobinfo_timeseries
(
   jid        VARCHAR(64) NOT NULL PRIMARY KEY,
   timestamp  MEDIUMTEXT,
   mem        MEDIUMTEXT,
   vmem       MEDIUMTEXT,
   cpuload    MEDIUMTEXT,
   cpufrac    MEDIUMTEXT,
   diskusage  MEDIUMTEXT
);
describe jobinfo_timeseries;
GRANT ALL ON monitor.* TO 'root'@'glidein-mon' IDENTIFIED BY 'sandhi';
GRANT ALL ON monitor.* TO 'root'@'glidein-mon.t2.ucsd.edu' IDENTIFIED BY 'sandhi';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_summary TO 'root'@'glidein-mon' IDENTIFIED BY 'sandhi';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_summary TO 'root'@'glidein-mon.t2.ucsd.edu' IDENTIFIED BY 'sandhi';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_timeseries TO 'root'@'glidein-mon' IDENTIFIED BY 'sandhi';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_timeseries TO 'root'@'glidein-mon.t2.ucsd.edu' IDENTIFIED BY 'sandhi';
GRANT SELECT ON monitor.* TO 'monitor'@'glidein-mon' IDENTIFIED BY 'sandhi';
GRANT SELECT ON monitor.* TO 'monitor'@'glidein-mon.t2.ucsd.edu' IDENTIFIED BY 'sandhi';
FLUSH PRIVILEGES;
use mysql;
select user,host,password from user;
