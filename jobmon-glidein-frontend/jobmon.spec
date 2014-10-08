Summary:  A Grid Job Monitoring package
Name: jobmon
Version: 1
Release: 0.01
License:GPL
Group: Monitor
Source: jobmon.tgz
URL:http://sarkar.web.cern.ch/sarkar/Welcome.html
Packager: Subir Sarkar

%description
A detailed user centric Grid job monitor suitable for Tier-2.
This package contains both the collector of information as well
as the Web Server side software.

%files
/opt/jobmon/data
/opt/jobmon/etc
/opt/jobmon/bin/cache_gridinfo.pl
/opt/jobmon/bin/cache_gridinfo.sh
/opt/jobmon/bin/cache_joblist.pl
/opt/jobmon/bin/cache_joblist.sh
/opt/jobmon/bin/getLSFInfo.sh
/opt/jobmon/bin/getPBSInfo.sh
/opt/jobmon/bin/jobsensor.pl
/opt/jobmon/bin/jobsensor.sh
/opt/jobmon/bin/launch_cache_gridinfo.sh
/opt/jobmon/bin/launch_cache_joblist.sh
/opt/jobmon/bin/launch_jobsensor.sh
/opt/jobmon/bin/launch_nodesensor.sh
/opt/jobmon/bin/monitor.cgi
/opt/jobmon/bin/monitor.pl
/opt/jobmon/bin/nodesensor.pl
/opt/jobmon/bin/nodesensor.sh
/opt/jobmon/bin/qstat.pl
/opt/jobmon/bin/qstat.sh
/opt/jobmon/cron.d/cache_gridinfo.cron
/opt/jobmon/cron.d/cache_joblist.cron
/opt/jobmon/cron.d/jobsensor.cron
/opt/jobmon/cron.d/nodesensor.cron
/opt/jobmon/sql/create_jobinfo_table.sql
/opt/jobmon/sql/create_wninfo_table.sql
/opt/jobmon/install/configure_jobmon
/opt/jobmon/install/install_jobmon
/opt/jobmon/install/jobmon.cfg
/opt/jobmon/lib/Collector/Condor
/opt/jobmon/lib/Collector/config.pl
/opt/jobmon/lib/Collector/ConfigReader.pm
/opt/jobmon/lib/Collector/GridiceInfo.pm
/opt/jobmon/lib/Collector/GridInfoCore.pm
/opt/jobmon/lib/Collector/GridInfo.pm
/opt/jobmon/lib/Collector/JobSensor.pm
/opt/jobmon/lib/Collector/JobStatus.pm
/opt/jobmon/lib/Collector/LSF
/opt/jobmon/lib/Collector/NodeInfo.pm
/opt/jobmon/lib/Collector/NodeSensor.pm
/opt/jobmon/lib/Collector/ObjectFactory.pm
/opt/jobmon/lib/Collector/PBS
/opt/jobmon/lib/Collector/StatusQuery.pm
/opt/jobmon/lib/Collector/Util.pm
/opt/jobmon/lib/Collector/LSF/CompletedJobInfo.pm
/opt/jobmon/lib/Collector/LSF/JobInfo.pm
/opt/jobmon/lib/Collector/LSF/JobList.pm
/opt/jobmon/lib/Collector/LSF/NodeInfo.pm
/opt/jobmon/lib/Collector/PBS/GridInfo.pm
/opt/jobmon/lib/Collector/PBS/NodeInfo.pm
/opt/jobmon/lib/WebService/config.pl
/opt/jobmon/lib/WebService/MonitorCore.pm
/opt/jobmon/lib/WebService/Monitor.pm
/opt/jobmon/lib/WebService/MonitorUtil.pm
