-- Procedure to insert datamart user.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-10

/**
 * Inserts a user in the datamart, with the values that do not change.
 */
CREATE OR REPLACE PROCEDURE dwh.insert_datamart_user (
  m_dimension_user_id INTEGER
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  m_user_id INTEGER;
  m_username VARCHAR(256);
  m_date_starting_creating_notes DATE;
  m_date_starting_solving_notes DATE;
  m_first_open_note_id INTEGER;
  m_first_commented_note_id INTEGER;
  m_first_closed_note_id INTEGER;
  m_first_reopened_note_id INTEGER;
 BEGIN
  SELECT user_id, username
   INTO m_user_id, m_username
  FROM dwh.dimension_users
  WHERE dimension_user_id = m_dimension_user_id;

  -- date_starting_creating_notes
  SELECT date_id
   INTO m_date_starting_creating_notes
  FROM dwh.dimension_days
  WHERE dimension_day_id = (
   SELECT MIN(opened_dimension_id_date)
   FROM dwh.facts f
   WHERE f.opened_dimension_id_user = m_dimension_user_id
  );
  
  -- date_starting_solving_notes
  SELECT date_id
   INTO m_date_starting_solving_notes
  FROM dwh.dimension_days
  WHERE dimension_day_id = (
   SELECT MIN(closed_dimension_id_date)
   FROM dwh.facts f
   WHERE f.closed_dimension_id_user = m_dimension_user_id
  );
  
  -- first_open_note_id
  SELECT id_note
   INTO m_first_open_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT MIN(fact_id)
   FROM dwh.facts f
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'opened'
  );

  -- first_commented_note_id
  SELECT id_note
   INTO m_first_commented_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT MIN(fact_id)
   FROM dwh.facts f
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'commented'
  );

  -- first_closed_note_id
  SELECT id_note
   INTO m_first_closed_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT MIN(fact_id)
   FROM dwh.facts f
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'closed'
  );

  -- first_reopened_note_id
  SELECT id_note
   INTO m_first_reopened_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT MIN(fact_id)
   FROM dwh.facts f
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'reopened'
  );

  INSERT INTO dwh.datamartUsers (
   dimension_user_id,
   user_id,
   username,
   date_starting_creating_notes,
   date_starting_solving_notes,
   first_open_note_id,
   first_commented_note_id,
   first_closed_note_id,
   first_reopened_note_id
  ) VALUES (
   m_dimension_user_id,
   m_user_id,
   m_username,
   m_date_starting_creating_notes,
   m_date_starting_solving_notes,
   m_first_open_note_id,
   m_first_commented_note_id,
   m_first_closed_note_id,
   m_first_reopened_note_id
  ) ON CONFLICT DO NOTHING;
 END
$proc$;

CREATE OR REPLACE PROCEDURE dwh.update_datamart_user_activity_year (
  m_dimension_user_id INTEGER,
  m_year SMALLINT
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
 m_history_year_open INTEGER;
 m_history_year_commented INTEGER;
 m_history_year_closed INTEGER;
 m_history_year_closed_with_comment INTEGER;
 m_history_year_reopened INTEGER;
 stmt TEXT;
 BEGIN
  -- history_year_open
  SELECT COUNT(1)
   INTO m_history_year_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'opened'
   AND EXTRACT(YEAR FROM d.date_id) = m_year;

  -- history_year_commented
  SELECT COUNT(1)
   INTO m_history_year_commented
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'commented'
   AND EXTRACT(YEAR FROM d.date_id) = m_year;

  -- history_year_closed
  SELECT COUNT(1)
   INTO m_history_year_closed
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'closed'
   AND EXTRACT(YEAR FROM d.date_id) = m_year;

  -- history_year_closed_with_comment
  -- TODO
  m_history_year_closed_with_comment := 0;

  -- history_year_reopened
  SELECT COUNT(1)
   INTO m_history_year_reopened
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'reopened'
   AND EXTRACT(YEAR FROM d.date_id) = m_year;

  stmt := 'UPDATE dwh.datamartUsers SET '
    || 'history_' || m_year || '_open = ' || m_history_year_open || ', '
    || 'history_' || m_year || '_commented = ' || m_history_year_commented || ', '
    || 'history_' || m_year || '_closed = ' || m_history_year_closed || ', '
    || 'history_' || m_year || '_closed_with_comment = ' || m_history_year_closed_with_comment || ', '
    || 'history_' || m_year || '_reopened = ' || m_history_year_reopened || ' '
    || 'WHERE dimension_user_id = ' || m_dimension_user_id;
  INSERT INTO logs (message) VALUES (stmt);
  EXECUTE stmt;
 END
$proc$;
