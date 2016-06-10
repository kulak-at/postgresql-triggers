
START TRANSACTION;
DO $$
DECLARE
  lock_var_id INT;
  row_var_id INT;
BEGIN

RAISE NOTICE '--- TEST 1: REGULAR INSERT ---';
-- Regular insert. Everything should work fine.
INSERT INTO lock(id) VALUES (DEFAULT) RETURNING id INTO lock_var_id;

RAISE NOTICE 'Lock Id: %', lock_var_id;

INSERT INTO data_view(value1,value2,lock_id) VALUES(10, 'abc', lock_var_id) RETURNING id INTO row_var_id;

RAISE NOTICE 'Row Id: %', row_var_id;

RAISE NOTICE '--- TEST 2: UPDATE WITHOUT LOCK WILL NOT WORK ---';
BEGIN
  -- It shouldn't work becouse there is no (lock_id, row_id) entity inside lock_rows
  UPDATE data_view SET (value1, lock_id)=(15,lock_var_id) WHERE id = row_var_id;
  RAISE NOTICE 'IT SHOULDNT HAPPEN';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'Worked - threw error: %', SQLERRM;
END;

RAISE NOTICE '--- TEST 3: UPDATE WITH LOCK WILL WORK---';
INSERT INTO lock_row(lock_id, data_id) VALUES(lock_var_id, row_var_id);

-- Now it should work.
UPDATE data_view SET (value1, lock_id)=(15,lock_var_id) WHERE id = row_var_id;

RAISE NOTICE '--- TEST 4: UPDATE WITH FINISHED LOCK WILL NOT WORK ---';
UPDATE lock SET (finished_at) = (NOW()) WHERE id = lock_var_id;

BEGIN
  UPDATE data_view SET (value1, lock_id) = (20, lock_var_id) WHERE id = row_var_id;
  RAISE NOTICE 'IT SHOULDNT HAPPEN';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'Worked - threw error:  %', SQLERRM;
END;

  -- INSERT INTO lock(id) VALUES(DEFAULT) RETURNING id INTO _lock1_id;
  -- INSERT INTO lock(id) VALUES(DEFAULT) RETURNING id INTO _lock2_id;
  -- RAISE NOTICE 'Created locks: %,%', _lock1_id, _lock2_id;

  -- INSERT INTO lock_row(lock_id, data_id) VALUES(_lock1_id, row_var_id);
  -- RAISE NOTICE 'It should work still.';
  -- INSERT INTO lock_row(lock_id, data_id) VALUES(_lock2_id, row_var_id); -- it should throw an error

-- EXCEPTION WHEN OTHERS THEN
--   RAISE NOTICE 'Workder - threw error: %', SQLERRM;

END $$;

DO $x$
DECLARE
  _lock1_id INT;
  _lock2_id INT;
  _row_var_id INT;
BEGIN
  BEGIN

    RAISE NOTICE '--- TEST 5: WE SHOULDNT BE ABLE TO LOCK ROW WHEN IT IS ALREADY LOCKED ---';
    INSERT INTO lock(id) VALUES(DEFAULT) RETURNING id INTO _lock1_id;
    INSERT INTO lock(id) VALUES(DEFAULT) RETURNING id INTO _lock2_id;
    INSERT INTO data_view(value1,value2,lock_id) VALUES(10, 'abc', _lock1_id) RETURNING id INTO _row_var_id;

    RAISE NOTICE 'Created locks: %, %', _lock1_id, _lock2_id;

    RAISE NOTICE 'Created row: %', _row_var_id;

    INSERT INTO lock_row(lock_id, data_id) VALUES(_lock1_id, _row_var_id);
    INSERT INTO lock_row(lock_id, data_id) VALUES(_lock2_id, _row_var_id); -- it should throw an error
    RAISE NOTICE 'SHOULDNT HAPPEN :(';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Worked: %', SQLERRM;
  END;

END $x$;

COMMIT;

-- TODO: disable ability to create second lock at the same data.
