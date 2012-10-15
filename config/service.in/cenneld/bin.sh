#!/bin/sh
exec 2>&1
export MYSQL_DSNS_JSON=@@INSTANCECONFIG@@/dsns.json
export KARASUMA_CONFIG_JSON=@@INSTANCECONFIG@@/@@INSTANCENAME@@.json
export KARASUMA_CONFIG_FILE_DIR_NAME=@@LOCAL@@/keys
export WEBUA_DEBUG=2
exec setuidgid @@USER@@ @@ROOT@@/perl @@ROOT@@/bin/runner.pl
