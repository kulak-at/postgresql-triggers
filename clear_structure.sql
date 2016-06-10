DROP FUNCTION data_view_insert_procedure() CASCADE;
DROP FUNCTION data_view_update_procedure() CASCADE;
DROP FUNCTION lock_row_no_parralel() CASCADE;
DROP FUNCTION util_blocking_trigger() CASCADE;

DROP VIEW data_view, active_lock, active_row_lock;

DROP TABLE data, lock, lock_row, data_history_row, data_history CASCADE;

DROP SEQUENCE data_id, lock_id, data_history_row_id, data_history_id;