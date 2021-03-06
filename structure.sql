CREATE EXTENSION hstore;

---------------
-- STRUCTURE --
---------------

CREATE SEQUENCE data_id;
CREATE TABLE data (
  id INTEGER PRIMARY KEY DEFAULT nextval('data_id'),
  value1 INTEGER NOT NULL DEFAULT 42,
  value2 TEXT NOT NULL DEFAULT 'HUEHUE'
);

CREATE SEQUENCE lock_id;
CREATE TABLE lock (
  id INTEGER PRIMARY KEY DEFAULT nextval('lock_id'), -- To make it more secure instead of this id we can use some token generation 
  started_at TIMESTAMP NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMP NULL DEFAULT NULL
);

CREATE TABLE lock_row (
  lock_id INTEGER NOT NULL REFERENCES lock(id),
  data_id INTEGER NOT NULL REFERENCES data(id),

  CONSTRAINT uniq_lock_data UNIQUE(lock_id, data_id)
);

CREATE SEQUENCE data_history_row_id;
CREATE TABLE data_history_row (
  id INTEGER PRIMARY KEY DEFAULT nextval('data_history_row_id'),

  -- Below there is "data" table definition with different id name.
  data_id INTEGER NOT NULL REFERENCES data(id),
  value1 INTEGER NOT NULL,
  value2 TEXT NOT NULL
);

CREATE SEQUENCE data_history_id;
CREATE TABLE data_history (
  id INTEGER PRIMARY KEY DEFAULT nextval('data_history_id'),
  data_history_row_id INTEGER NOT NULL REFERENCES data_history_row(id), -- it references to data_history_row which is a copy of row at the time
  lock_id INTEGER NOT NULL REFERENCES lock(id),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT uniq_data_history_row_id UNIQUE(data_history_row_id)
);

-----------
-- VIEWS --
-----------

CREATE VIEW data_view AS (
  SELECT data.*, null::INT AS lock_id FROM data
);

CREATE VIEW active_lock AS (
  SELECT * FROM lock WHERE finished_at IS NULL AND started_at > (NOW() - interval '15 minutes')
);

CREATE VIEW active_row_lock AS (
  SELECT * FROM lock_row WHERE lock_id IN (SELECT id FROM active_lock)
);


-----------------------
-- TRIGGER FUNCTIONS --
-----------------------

/*
  Reference:
  Function declaration: https://www.postgresql.org/docs/9.1/static/plpgsql-declarations.html
  Triggers: https://www.postgresql.org/docs/9.1/static/plpgsql-trigger.html
  Create Trigger Syntax: https://www.postgresql.org/docs/9.1/static/sql-createtrigger.html

*/

CREATE FUNCTION data_view_insert_procedure() RETURNS trigger AS $end$
BEGIN
  -- Note: Trigger function gets two objects it can use internaly OLD.* and NEW.* (also with all other less-important stuff)
  -- For update both are present, for insert OLD does not exists, for delete NEW does not exists (it's quite logical :))
  -- You can use this data to make all magic 
  WITH inserted_data AS (
    INSERT INTO data (value1, value2)
    VALUES (NEW.value1, NEW.value2) RETURNING *
  ), inserted_data_history_row AS (
    INSERT INTO data_history_row (data_id,value1,value2) SELECT id,value1,value2 FROM inserted_data RETURNING *
  ),
  inserted_data_history AS (
    INSERT INTO data_history (data_history_row_id, lock_id, created_at) SELECT id, NEW.lock_id, NOW() FROM inserted_data_history_row RETURNING *
  )
  SELECT id FROM inserted_data INTO NEW.id;

  RETURN NEW;
END
$end$ LANGUAGE plpgsql;


CREATE FUNCTION data_view_update_procedure() RETURNS trigger AS $end$
DECLARE
  var_id INT;
BEGIN

  -- Checks first
  IF ((SELECT COUNT(*) FROM active_lock WHERE id = NEW.lock_id) = 0) THEN
    RAISE EXCEPTION 'Lock % is already finished or its lifetime ended', NEW.lock_id;
  END IF;
  IF ((SELECT COUNT(*) FROM lock_row WHERE lock_id = NEW.lock_id AND data_id = NEW.id) = 0) THEN
    RAISE EXCEPTION 'Lock % does not lock row %', NEW.lock_id, NEW.id;
  END IF;



  WITH updated_data AS (
    UPDATE data SET (value1, value2) = (NEW.value1, NEW.value2)
    WHERE id = NEW.id RETURNING *
  ),
  inserted_data_history_row AS (
    INSERT INTO data_history_row (data_id,value1,value2) SELECT id,value1,value2 FROM updated_data RETURNING *
  ),
  inserted_data_history AS (
    INSERT INTO data_history (data_history_row_id, lock_id, created_at) SELECT id, NEW.lock_id, NOW() FROM inserted_data_history_row RETURNING *
  )
  SELECT id FROM inserted_data_history INTO var_id; -- This is hack, plpgsql language forbids performing selects without destination inside functions so we use dumb destination.
  RETURN NEW;
END
$end$ LANGUAGE plpgsql;

CREATE FUNCTION lock_row_no_parralel() RETURNS trigger AS $end$
BEGIN
  IF ((SELECT COUNT(*) FROM active_row_lock WHERE data_id = NEW.data_id) > 0) THEN
    RAISE EXCEPTION 'Row % is already locked!', NEW.data_id;
  END IF;
  RETURN NEW;
END
$end$ LANGUAGE plpgsql;

CREATE FUNCTION util_blocking_trigger() RETURNS trigger AS $end$
BEGIN
  RAISE EXCEPTION 'Operation blocked!';
END
$end$ LANGUAGE plpgsql;

--------------
-- TRIGGERS --
--------------

-- Trigger when we create new row
CREATE TRIGGER data_view_insert
  INSTEAD OF INSERT ON data_view
  FOR EACH ROW
  EXECUTE PROCEDURE data_view_insert_procedure();

-- Trigger when we update value
CREATE TRIGGER data_view_update
  INSTEAD OF UPDATE on data_view
  FOR EACH ROW
  -- WHEN (OLD.* IS DISTINCT FROM NEW.*) -- only when something changed
  EXECUTE PROCEDURE data_view_update_procedure();


-- Trigger that prevents from blocking the same row in two ongoing transactions
CREATE TRIGGER lock_row_no_parralel_trigger
  BEFORE INSERT ON lock_row
  FOR EACH ROW
  EXECUTE PROCEDURE lock_row_no_parralel();

-- Lock row - block update.
CREATE TRIGGER lock_row_block_update
  BEFORE UPDATE ON lock_row
  EXECUTE PROCEDURE util_blocking_trigger();
