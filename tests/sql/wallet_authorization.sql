-- Rollback-only authorization checks. Reuses the existing PostgreSQL
-- integration assertions rather than duplicating their fixtures/assertions.
-- Run only against an isolated local database after database_bootstrap.sql
-- and supabase_setup.sql; never run against Supabase or production.
\set ON_ERROR_STOP on
\ir ../../test/database_verification_test.sql
