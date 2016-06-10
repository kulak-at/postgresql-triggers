DROP FUNCTION data_view_insert_procedure() CASCADE;
DROP FUNCTION data_view_update_procedure() CASCADE;

DROP VIEW data_view;

DROP TABLE data, lock, lock_row, data_history_row, data_history CASCADE;

DROP SEQUENCE data_id, lock_id, data_history_row_id, data_history_id;