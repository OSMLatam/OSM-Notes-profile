-- Adds the sequence for comments and change the table properties to validate
-- this.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-05

DO /* Notes-processPlanet-assignSequence */
$$
DECLARE
  m_current_note_id INTEGER;
  m_previous_note_id INTEGER;
  m_sequence_value INTEGER;
  m_rec_note_comment RECORD;
  m_note_comments_cursor CURSOR  FOR
   SELECT
    note_id
   FROM note_comments
   ORDER BY note_id, id
   FOR UPDATE;

 BEGIN
  OPEN m_note_comments_cursor;

  LOOP
   FETCH m_note_comments_cursor INTO m_rec_note_comment;
   -- Exit when no more rows to fetch.
   EXIT WHEN NOT FOUND;

   m_current_note_id := m_rec_note_comment.note_id;
   IF (m_previous_note_id = m_current_note_id) THEN
    m_sequence_value := m_sequence_value + 1;
   ELSE
    m_sequence_value := 1;
    m_previous_note_id := m_current_note_id;
   END IF;

   UPDATE note_comments
    SET sequence_action = m_sequence_value
    WHERE CURRENT OF m_note_comments_cursor;
  END LOOP;

  CLOSE m_note_comments_cursor;

END
$$;

ALTER TABLE note_comments ALTER COLUMN sequence_action SET NOT NULL;

CREATE UNIQUE INDEX sequence_note_comment
 ON note_comments
 (note_id, sequence_action);
COMMENT ON INDEX sequence_note_comment IS 'Sequence of comments creation';
ALTER TABLE note_comments
 ADD CONSTRAINT unique_comment_note
 UNIQUE USING INDEX sequence_note_comment;

CREATE OR REPLACE FUNCTION put_seq_on_comment()
  RETURNS TRIGGER AS
 $$
 DECLARE
  max_value INTEGER;
 BEGIN
   SELECT MAX(sequence_action)
    INTO max_value
   FROM note_comments
   WHERE note_id = NEW.note_id;
   IF (max_value IS NULL) THEN
    max_value := 1;
   ELSE
    max_value := max_value + 1;
   END IF;
   NEW.sequence_action := max_value;

   RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION put_seq_on_comment IS
  'Assigns the sequence value for the comments on the same note';

CREATE OR REPLACE TRIGGER put_seq_on_comment_trigger
  BEFORE INSERT ON note_comments
  FOR EACH ROW
  EXECUTE FUNCTION put_seq_on_comment()
;
COMMENT ON TRIGGER put_seq_on_comment_trigger ON note_comments IS
  'Trigger to assign the sequence value';