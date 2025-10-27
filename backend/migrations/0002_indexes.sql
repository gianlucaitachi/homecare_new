CREATE INDEX IF NOT EXISTS users_email_idx ON users (email);
CREATE INDEX IF NOT EXISTS tasks_assignee_idx ON tasks (assignee);
CREATE INDEX IF NOT EXISTS tasks_due_date_idx ON tasks (due_date);
