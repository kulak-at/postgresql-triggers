START TRANSACTION;
DO $$
DECLARE
  lock_var_id INT;
  row_var_id INT;
BEGIN
INSERT INTO lock(id) VALUES (DEFAULT) RETURNING id INTO lock_var_id;

RAISE NOTICE 'Lock Id: %', lock_var_id;

INSERT INTO data_view(value1,value2,lock_id) VALUES(10, 'abc', lock_var_id) RETURNING id INTO row_var_id;

RAISE NOTICE 'Row Id: %', row_var_id;

UPDATE data_view SET (value1, lock_id)=(15,lock_var_id) WHERE id = row_var_id;

END $$;

COMMIT;