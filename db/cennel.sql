CREATE TABLE `repository` (
  repository_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  url VARCHAR(1023) NOT NULL,
  created DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (repository_id),
  UNIQUE KEY (name),
  KEY (url),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `role` (
  role_id BIGINT UNSIGNED NOT NULL,
  repository_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  created DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (role_id),
  UNIQUE KEY (repository_id, name),
  KEY (repository_id, created),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `host` (
  host_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  created DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (host_id),
  UNIQUE KEY (name),
  KEY (created)
) DEFAULT CHARSET=BINARY;
