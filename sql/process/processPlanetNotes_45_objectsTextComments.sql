-- Modify text comments table.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-11

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Changing sequence text comment - adding foreign key and trigger' AS Text;

ALTER TABLE note_comments_text ALTER COLUMN sequence_action SET NOT NULL;

CREATE UNIQUE INDEX unique_comment_note_text
 ON note_comments_text
 (note_id, sequence_action);
COMMENT ON INDEX unique_comment_note_text IS 'Sequence of comments creation';
ALTER TABLE note_comments_text
 ADD CONSTRAINT unique_comment_note_text
 UNIQUE USING INDEX unique_comment_note_text;

ALTER TABLE note_comments_text
 ADD CONSTRAINT fk_note_comment_uniq
 FOREIGN KEY (note_id, sequence_action)
 REFERENCES note_comments (note_id, sequence_action);

CREATE OR REPLACE FUNCTION put_seq_on_text_comment()
  RETURNS TRIGGER AS
 $$
 DECLARE
  max_value INTEGER;
 BEGIN
  IF (NEW.sequence_action IS NULL) THEN
   SELECT /* Notes-processPlanet */ MAX(sequence_action)
    INTO max_value
   FROM note_comments_text
   WHERE note_id = NEW.note_id;
   IF (max_value IS NULL) THEN
    max_value := 1;
   ELSE
    max_value := max_value + 1;
   END IF;
   NEW.sequence_action := max_value;
  END IF;

  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION put_seq_on_text_comment IS
  'Assigns the sequence value for the text comments on the same note';

CREATE OR REPLACE TRIGGER put_seq_on_text_comment_trigger
  BEFORE INSERT ON note_comments_text
  FOR EACH ROW
  EXECUTE FUNCTION put_seq_on_text_comment()
;
COMMENT ON TRIGGER put_seq_on_text_comment_trigger ON note_comments_text IS
  'Trigger to assign the sequence value';

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Sequence changed text comment' AS Text;
