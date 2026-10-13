CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT,
    email TEXT,
    role TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users_audit (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by TEXT,
    field_changed TEXT,
    old_value TEXT,
    new_value TEXT
);

insert into users (name, email, role)
values 
	('Alice', 'alice@ya.ru', 'Manager'),
	('Bob', 'bob@ya.ru', 'Manager'),
	('Lisa', 'lisa@ya.ru', 'Director'),
	('Rob', 'rob@ya.ru', 'Sale manager');


create or replace function def_logs()
returns trigger as $$
begin
	new.updated_at := current_timestamp;
	if old.name <> new.name then
	insert into users_audit (user_id, changed_by, field_changed, old_value, new_value)
	values (new.id, current_user, 'name', old.name, new.name);
	end if;
	if old.email <> new.email then
	insert into users_audit (user_id, changed_by, field_changed, old_value, new_value)
	values (new.id, current_user, 'email', old.email, new.email);
	end if;
	if old.role <> new.role then
	insert into users_audit (user_id, changed_by, field_changed, old_value, new_value)
	values (new.id, current_user, 'role', old.role, new.role);
	end if;
	return new;
end;
$$ language plpgsql;


create trigger trigger_log
before update on users
for each row
execute function def_logs();


update users u 
set name = 'Pedro',
email = 'Pedro@ya.ru',
role = 'Data Engineer'
where name = 'Bob';


create extension if not exists pg_cron;

select *
from users_audit ua 
where ua.changed_at >= current_date - 1 and ua.changed_at < current_date;


copy (select *
from users_audit ua 
where ua.changed_at >= current_date - 1 and ua.changed_at < current_date)
to '/tmp/users_audit_export_20261012_2242.csv'
with (format csv, header);

create or replace function def_date_file()
returns void as $$
declare 
	file_path text;
begin
	file_path := '/tmp/users_audit_export_' || to_char(current_date - 1, 'DD.MM.YYYY') || '.csv';
	execute format('copy (select *
	from users_audit ua 
	where ua.changed_at >= current_date - 1 and ua.changed_at < current_date)
	to %L
	with (format csv, header);', file_path);
end;
$$ language plpgsql;

select def_date_file();

select cron.schedule(
	'daily_audit_logs',
	'0 3 * * *',
	'select def_date_file();'
);
	

select * from cron.job;