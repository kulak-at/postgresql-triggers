# Postgresql Triggers

This is an example how to use triggers to autogenerate history updates and track under which transaction the change was performed. It also prevents two locks to edit the same data when second lock is currently locking some row.

## How to run it?
Use following commands to create structure and run tests
```
psql -d postgresql-triggers < structure.sql
psql -d postgresql-triggers < example1.sql
```