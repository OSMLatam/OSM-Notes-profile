-- Drop base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-02-17

DROP FUNCTION IF EXISTS get_country;
DROP PROCEDURE IF EXISTS insert_note_comment;
DROP PROCEDURE IF EXISTS insert_note;
DROP TRIGGER IF EXISTS update_note ON note_comments;
DROP FUNCTION IF EXISTS update_note;
DROP TRIGGER IF EXISTS log_insert_note ON notes;
DROP FUNCTION IF EXISTS log_insert_note;
DROP TABLE IF EXISTS properties;
DROP TABLE IF EXISTS note_comments_check;
DROP TABLE IF EXISTS notes_check;
DROP TABLE IF EXISTS note_comments_text;
DROP TABLE IF EXISTS note_comments;
DROP TABLE IF EXISTS notes;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS logs;
DROP TYPE note_event_enum;
DROP TYPE note_status_enum;
