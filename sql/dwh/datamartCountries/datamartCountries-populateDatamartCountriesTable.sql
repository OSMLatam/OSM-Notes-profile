-- Populates datamart for countries.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-09

DO
$$
DECLARE
 r RECORD;
 qty SMALLINT;
 m_last_year_activity SMALLINT;
 m_lastest_open_note_id INTEGER;
 m_lastest_commented_note_id INTEGER;
 m_lastest_closed_note_id INTEGER;
 m_lastest_reopened_note_id INTEGER;
 m_date_most_open DATE;
 m_date_most_open_qty SMALLINT;
 m_date_most_closed DATE;
 m_date_most_closed_qty SMALLINT;
 m_hashtags JSON;
 m_users_open_notes JSON;
 m_users_solving_notes JSON;
 m_working_hours_opening JSON;
 m_working_hours_commenting JSON;
 m_working_hours_closing JSON;
 m_history_whole_open INTEGER; -- Qty opened notes.
 m_history_whole_commented INTEGER; -- Qty commented notes.
 m_history_whole_closed INTEGER; -- Qty closed notes.
 m_history_whole_closed_with_comment INTEGER; -- Qty closed notes with comments.
 m_history_whole_reopened INTEGER; -- Qty reopened notes.
 m_history_year_open INTEGER; -- Qty in the current year.
 m_history_year_commented INTEGER;
 m_history_year_closed INTEGER;
 m_history_year_closed_with_comment INTEGER;
 m_history_year_reopened INTEGER;
 m_history_month_open INTEGER; -- Qty in the current month.
 m_history_month_commented INTEGER;
 m_history_month_closed INTEGER;
 m_history_month_closed_with_comment INTEGER;
 m_history_month_reopened INTEGER;
 m_history_day_open INTEGER; -- Qty in the current day.
 m_history_day_commented INTEGER;
 m_history_day_closed INTEGER;
 m_history_day_closed_with_comment INTEGER;
 m_history_day_reopened INTEGER;

 m_year SMALLINT;
 m_current_year SMALLINT;
 m_current_month SMALLINT;
 m_current_day SMALLINT;
BEGIN
 FOR r IN
  -- Process the datamart only for modified countries.
  SELECT f.dimension_id_country
  FROM dwh.facts f
   JOIN dwh.dimension_countries c
   ON (f.dimension_id_country = c.dimension_country_id)
  WHERE c.modified = TRUE
  GROUP BY f.dimension_id_country
  ORDER BY MAX(f.action_at) DESC
 LOOP
  SELECT COUNT(1)
   INTO qty
   FROM dwh.datamartCountries
   WHERE dimension_country_id = r.dimension_id_country;
  IF (qty = 0) THEN
   RAISE NOTICE 'Inserting country';
   CALL dwh.insert_datamart_country(r.dimension_id_country);
  ELSE
   RAISE NOTICE 'Country does not exist';
  END IF;

  -- last_year_activity
  SELECT EXTRACT(YEAR FROM date_id)
   INTO m_last_year_activity
  FROM dwh.dimension_days
  WHERE dimension_day_id = (
   SELECT MAX(action_dimension_id_date)
   FROM dwh.facts f
   WHERE f.dimension_id_country = r.dimension_id_country
  );

  -- lastest_open_note_id
  SELECT id_note
   INTO m_lastest_open_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT MAX(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = r.dimension_id_country
  );

  -- lastest_commented_note_id
  SELECT id_note
   INTO m_lastest_commented_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT MAX(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = r.dimension_id_country
    AND f.action_comment = 'commented'
  );

  -- lastest_closed_note_id
  SELECT id_note
   INTO m_lastest_closed_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT MAX(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = r.dimension_id_country
  );

  -- lastest_reopened_note_id
  SELECT id_note
   INTO m_lastest_reopened_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT MAX(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = r.dimension_id_country
    AND f.action_comment = 'reopened'
  );

  -- date_most_open
  SELECT date_id, COUNT(1)
   INTO m_date_most_open, m_date_most_open_qty
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.opened_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
  GROUP BY date_id
  ORDER BY COUNT(1) DESC
  FETCH FIRST 1 ROWS ONLY;

  -- date_most_closed
  SELECT date_id, COUNT(1)
   INTO m_date_most_closed, m_date_most_closed_qty
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.closed_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
  GROUP BY date_id
  ORDER BY COUNT(1) DESC
  FETCH FIRST 1 ROWS ONLY;

  -- hashtags
  -- TODO
  m_hashtags := NULL;

  -- users_open_notes
  SELECT JSON_AGG(username)
   INTO m_users_open_notes
  FROM (
   SELECT username 
   FROM dwh.facts f
    JOIN dwh.dimension_users u
    ON f.opened_dimension_id_user = u.dimension_user_id
   WHERE f.dimension_id_country = r.dimension_id_country
   GROUP BY username
  ) AS T;

  -- users_solving_notes
  SELECT JSON_AGG(username)
   INTO m_users_solving_notes
  FROM (
   SELECT username
   FROM dwh.facts f
    JOIN dwh.dimension_users u
    ON f.closed_dimension_id_user = u.dimension_user_id
   WHERE  f.dimension_id_country = r.dimension_id_country
   GROUP BY username
  ) AS T;

  -- working_hours_opening
  WITH hours AS (
   SELECT opened_dimension_id_hour, COUNT(1)
   FROM dwh.facts f
    JOIN dwh.dimension_times t
    ON f.opened_dimension_id_hour = t.dimension_time_id
   WHERE f.dimension_id_country = r.dimension_id_country
    AND f.action_comment = 'opened'
   GROUP BY opened_dimension_id_hour
  )
  SELECT JSON_AGG(hours.*)
   INTO m_working_hours_opening
  FROM hours;

  -- working_hours_commenting
  WITH hours AS (
   SELECT action_dimension_id_hour, COUNT(1)
   FROM dwh.facts f
    JOIN dwh.dimension_times t
    ON f.action_dimension_id_hour = t.dimension_time_id
   WHERE f.dimension_id_country = r.dimension_id_country
    AND f.action_comment = 'commented'
   GROUP BY action_dimension_id_hour
  )
  SELECT JSON_AGG(hours.*)
   INTO m_working_hours_commenting
  FROM hours;

  -- working_hours_closing
  WITH hours AS (
   SELECT closed_dimension_id_hour, COUNT(1)
   FROM dwh.facts f
    JOIN dwh.dimension_times t
    ON f.closed_dimension_id_hour = t.dimension_time_id
   WHERE f.dimension_id_country = r.dimension_id_country
   GROUP BY closed_dimension_id_hour
  )
  SELECT JSON_AGG(hours.*)
   INTO m_working_hours_closing
  FROM hours;

  -- history_whole_open
  SELECT COUNT(1)
   INTO m_history_whole_open
  FROM dwh.facts f
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'opened';

  -- history_whole_commented
  SELECT COUNT(1)
   INTO m_history_whole_commented
  FROM dwh.facts f
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'commented';

  -- history_whole_closed
  SELECT COUNT(1)
   INTO m_history_whole_closed
  FROM dwh.facts f
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'closed';

  -- history_whole_closed_with_comment
  -- TODO
  m_history_whole_closed_with_comment := 0;

  -- history_whole_reopened
  SELECT COUNT(1)
   INTO m_history_whole_reopened
  FROM dwh.facts f
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'reopened';

  SELECT EXTRACT(YEAR FROM CURRENT_TIMESTAMP)
   INTO m_current_year;

  -- history_year_open
  SELECT COUNT(1)
   INTO m_history_year_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'opened'
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_year_commented
  SELECT COUNT(1)
   INTO m_history_year_commented
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'commented'
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_year_closed
  SELECT COUNT(1)
   INTO m_history_year_closed
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'closed'
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_year_closed_with_comment
  -- TODO
  m_history_year_closed_with_comment := 0;

  -- history_year_reopened
  SELECT COUNT(1)
   INTO m_history_year_reopened
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'reopened'
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  SELECT EXTRACT(MONTH FROM CURRENT_TIMESTAMP)
   INTO m_current_month;

  -- history_month_open
  SELECT COUNT(1)
   INTO m_history_month_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'opened'
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month;

  -- history_month_commented
  SELECT COUNT(1)
   INTO m_history_month_commented
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'commented'
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month;

  -- history_month_closed
  SELECT COUNT(1)
   INTO m_history_month_closed
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'closed'
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month;

  -- history_month_closed_with_comment
  -- TODO
  m_history_month_closed_with_comment := 0;

  -- history_month_reopened
  SELECT COUNT(1)
   INTO m_history_month_reopened
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'reopened'
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month;

  SELECT EXTRACT(DAY FROM CURRENT_TIMESTAMP)
   INTO m_current_day;

  -- history_day_open
  SELECT COUNT(1)
   INTO m_history_day_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'opened'
   AND EXTRACT(DAY FROM d.date_id) = m_current_day;

  -- history_day_commented
  SELECT COUNT(1)
   INTO m_history_day_commented
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'commented'
   AND EXTRACT(DAY FROM d.date_id) = m_current_day;

  -- history_day_closed
  SELECT COUNT(1)
   INTO m_history_day_closed
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'closed'
   AND EXTRACT(DAY FROM d.date_id) = m_current_day;

  -- history_day_closed_with_comment
  -- TODO
  m_history_day_closed_with_comment := 0;

  -- history_day_reopened
  SELECT COUNT(1)
   INTO m_history_day_reopened
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = r.dimension_id_country
   AND f.action_comment = 'reopened'
   AND EXTRACT(DAY FROM d.date_id) = m_current_day;

  -- Updates country with new values.
  UPDATE dwh.datamartCountries
  SET 
   last_year_activity = m_last_year_activity,
   lastest_open_note_id = m_lastest_open_note_id,
   lastest_commented_note_id = m_lastest_commented_note_id,
   lastest_closed_note_id = m_lastest_closed_note_id,
   lastest_reopened_note_id = m_lastest_reopened_note_id,
   date_most_open = m_date_most_open,
   date_most_open_qty = m_date_most_open_qty,
   date_most_closed = m_date_most_closed,
   date_most_closed_qty = m_date_most_closed_qty,
   hashtags = m_hashtags,
   users_open_notes = m_users_open_notes,
   users_solving_notes = m_users_solving_notes,
   working_hours_opening = m_working_hours_opening,
   working_hours_commenting = m_working_hours_commenting,
   working_hours_closing = m_working_hours_closing,
   history_whole_open = m_history_whole_open,
   history_whole_commented = m_history_whole_commented,
   history_whole_closed = m_history_whole_closed,
   history_whole_reopened = m_history_whole_reopened,
   history_year_open = m_history_year_open,
   history_year_commented = m_history_year_commented,
   history_year_closed = m_history_year_closed,
   history_year_closed_with_comment = m_history_year_closed_with_comment,
   history_year_reopened = m_history_year_reopened,
   history_month_open = m_history_month_open,
   history_month_commented = m_history_month_commented,
   history_month_closed = m_history_month_closed,
   history_month_closed_with_comment = m_history_month_closed_with_comment,
   history_month_reopened = m_history_month_reopened,
   history_day_open = m_history_day_open,
   history_day_commented = m_history_day_commented,
   history_day_closed = m_history_day_closed,
   history_day_closed_with_comment = m_history_day_closed_with_comment,
   history_day_reopened =m_history_day_reopened
  WHERE dimension_country_id = r.dimension_id_country;

  UPDATE dwh.dimension_countries
   SET modified = FALSE
   WHERE dimension_country_id = r.dimension_id_country;

  WHILE (m_year < m_current_year) LOOP
   CALL dwh.update_datamart_country_activity_year(r.dimension_id_country, m_year);
   m_year := m_year + 1;
  END LOOP;
  COMMIT;
 END LOOP;
END
$$;