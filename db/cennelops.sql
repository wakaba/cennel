CREATE TABLE `operation` (
  operation_id BIGINT UNSIGNED NOT NULL,
  repository_id BIGINT UNSIGNED NOT NULL,
  repository_branch VARCHAR(511) NOT NULL,
  repository_sha BINARY(40) NOT NULL,
  role_id BIGINT UNSIGNED NOT NULL,
  task_name VARCHAR(255) NOT NULL,
  args MEDIUMBLOB NOT NULL,
  status SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  data MEDIUMBLOB NOT NULL DEFAULT '',
  start_timestamp DOUBLE NOT NULL DEFAULT 0,
  end_timestamp DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (operation_id), 
  KEY (repository_id, role_id, start_timestamp),
  KEY (repository_id, start_timestamp),
  KEY (start_timestamp),
  KEY (end_timestamp)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `operation_unit` (
  operation_unit_id BIGINT UNSIGNED NOT NULL,
  operation_id BIGINT UNSIGNED NOT NULL,
  host_id BIGINT UNSIGNED NOT NULL,
  args MEDIUMBLOB NOT NULL,
  status SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  data MEDIUMBLOB NOT NULL DEFAULT '',
  scheduled_timestamp DOUBLE NOT NULL DEFAULT 0,
  start_timestamp DOUBLE NOT NULL DEFAULT 0,
  end_timestamp DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (operation_unit_id),
  KEY (operation_id, start_timestamp),
  KEY (host_id, start_timestamp),
  KEY (operation_id, host_id, start_timestamp),
  KEY (start_timestamp),
  KEY (end_timestamp)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `operation_unit_job` (
  operation_unit_id BIGINT UNSIGNED NOT NULL,
  operation_id BIGINT UNSIGNED NOT NULL,
  scheduled_timestamp DOUBLE NOT NULL DEFAULT 0,
  process_id BIGINT UNSIGNED NOT NULL,
  process_started DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (operation_unit_id),
  KEY (operation_id, scheduled_timestamp),
  KEY (process_id, process_started),
  KEY (process_started, scheduled_timestamp),
  KEY (scheduled_timestamp)
) DEFAULT CHARSET=BINARY;
