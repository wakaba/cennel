alter table operation_unit_job
  add column repository_id BIGINT UNSIGNED NOT NULL,
  add column repository_branch VARCHAR(511) NOT NULL,
  add column role_id BIGINT UNSIGNED NOT NULL,
  add column task_name VARCHAR(255) NOT NULL;
