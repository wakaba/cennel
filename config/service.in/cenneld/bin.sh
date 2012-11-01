#!/bin/sh
exec 2>&1
export MYSQL_DSNS_JSON=@@INSTANCECONFIG@@/dsns.json
export KARASUMA_CONFIG_JSON=@@INSTANCECONFIG@@/@@INSTANCENAME@@.json
export KARASUMA_CONFIG_FILE_DIR_NAME=@@LOCAL@@/keys

export SQL_DEBUG=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl env.SQL_DEBUG text`
export WEBUA_DEBUG=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl env.WEBUA_DEBUG text`
export CENNEL_DEBUG=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl env.CENNEL_DEBUG text`

exec setuidgid @@USER@@ @@ROOT@@/perl @@ROOT@@/bin/runner.pl
