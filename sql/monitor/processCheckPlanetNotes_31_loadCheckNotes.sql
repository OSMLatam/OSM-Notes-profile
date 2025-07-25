-- Loads check notes.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-11

TRUNCATE TABLE notes_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Uploading check notes' AS Text;
COPY notes_check (note_id, latitude, longitude, created_at, closed_at,
 status)
FROM '${OUTPUT_NOTES_FILE}' csv;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Statistics on notes check' AS Text;
ANALYZE notes_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Counting check notes' AS Text;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded check notes' AS Text
FROM notes_check;

TRUNCATE TABLE note_comments_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Uploading check comments' AS Text;
COPY note_comments_check (note_id, event, created_at, id_user, username)
FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Statistics on comments check' AS Text;
ANALYZE note_comments_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Counting check comments' AS Text;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded check comments' AS Text
FROM note_comments_check;

TRUNCATE TABLE note_comments_text_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Uploading check text comments' AS Text;
COPY note_comments_text_check (note_id, body)
FROM '${OUTPUT_TEXT_COMMENTS_FILE}' csv;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Statistics on text comments check' AS Text;
ANALYZE note_comments_text_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Counting check text comments' AS Text;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded check text comments' AS Text
FROM note_comments_text_check;

DO /* Notes-processPlanet-assignSequence */
$$
DECLARE
  m_current_note_id INTEGER;
  m_previous_note_id INTEGER;
  m_sequence_value INTEGER;
  m_rec_note_comment RECORD;
  m_note_comments_cursor CURSOR  FOR
   SELECT /* Notes-check */ note_id
   FROM note_comments_check
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

   UPDATE note_comments_check
    SET sequence_action = m_sequence_value
    WHERE CURRENT OF m_note_comments_cursor;
  END LOOP;

  CLOSE m_note_comments_cursor;

END
$$;

-- Assign sequence_action to text comments based on note_id order
DO /* Notes-processPlanet-assignSequenceText */
$$
DECLARE
  m_current_note_id INTEGER;
  m_previous_note_id INTEGER;
  m_sequence_value INTEGER;
  m_rec_text_comment RECORD;
  m_text_comments_cursor CURSOR  FOR
   SELECT /* Notes-check */ note_id
   FROM note_comments_text_check
   ORDER BY note_id, id
   FOR UPDATE;

 BEGIN
  OPEN m_text_comments_cursor;

  LOOP
   FETCH m_text_comments_cursor INTO m_rec_text_comment;
   -- Exit when no more rows to fetch.
   EXIT WHEN NOT FOUND;

   m_current_note_id := m_rec_text_comment.note_id;
   IF (m_previous_note_id = m_current_note_id) THEN
    m_sequence_value := m_sequence_value + 1;
   ELSE
    m_sequence_value := 1;
    m_previous_note_id := m_current_note_id;
   END IF;

   UPDATE note_comments_text_check
    SET sequence_action = m_sequence_value
    WHERE CURRENT OF m_text_comments_cursor;
  END LOOP;

  CLOSE m_text_comments_cursor;

END
$$;
