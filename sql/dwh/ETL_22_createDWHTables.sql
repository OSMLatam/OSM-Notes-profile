-- Create data warehouse tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-27

CREATE SCHEMA IF NOT EXISTS dwh;
COMMENT ON SCHEMA dwh IS
  'Data warehouse objects';

CREATE TABLE IF NOT EXISTS dwh.facts (
 fact_id SERIAL,
 id_note INTEGER NOT NULL,
 sequence_action INTEGER,
 dimension_id_country INTEGER NOT NULL,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
 action_at TIMESTAMP NOT NULL,
 action_comment note_event_enum NOT NULL,
 action_dimension_id_date INTEGER NOT NULL,
 action_dimension_id_hour_of_week SMALLINT NOT NULL,
 action_dimension_id_user INTEGER,
 opened_dimension_id_date INTEGER NOT NULL,
 opened_dimension_id_hour_of_week SMALLINT NOT NULL,
 opened_dimension_id_user INTEGER,
 closed_dimension_id_date INTEGER,
 closed_dimension_id_hour_of_week SMALLINT,
 closed_dimension_id_user INTEGER,
 dimension_application_creation INTEGER,
 recent_opened_dimension_id_date INTEGER, -- Later converted to NOT NULL
 days_to_resolution INTEGER,
 days_to_resolution_active INTEGER,
 days_to_resolution_from_reopen INTEGER,
 hashtag_1 INTEGER,
 hashtag_2 INTEGER,
 hashtag_3 INTEGER,
 hashtag_4 INTEGER,
 hashtag_5 INTEGER,
 hashtag_number INTEGER
);
-- Note: Any new column should be included in:
-- staging.process_notes_at_date_${YEAR} (initialFactsLoadCreate)
-- staging.process_notes_at_date (createStagingObjects)
-- ETL.sh > __initialFacts
COMMENT ON TABLE dwh.facts IS 'Facts id, center of the star schema';
COMMENT ON COLUMN dwh.facts.fact_id IS 'Surrogated ID';
COMMENT ON COLUMN dwh.facts.id_note IS 'OSM note id';
COMMENT ON COLUMN dwh.facts.sequence_action IS 'Creation sequence';
COMMENT ON COLUMN dwh.facts.dimension_id_country IS 'OSM country relation id';
COMMENT ON COLUMN dwh.facts.processing_time IS
  'Timestamp when the comment was processed';
COMMENT ON COLUMN dwh.facts.action_at IS
 'Timestamp when the action took place';
COMMENT ON COLUMN dwh.facts.action_comment IS 'Type of comment action';
COMMENT ON COLUMN dwh.facts.action_dimension_id_date IS 'Date of the action';
COMMENT ON COLUMN dwh.facts.action_dimension_id_hour_of_week IS
  'Hour of the week action';
COMMENT ON COLUMN dwh.facts.action_dimension_id_user IS
  'User who performed the action';
COMMENT ON COLUMN dwh.facts.opened_dimension_id_date IS
  'Date when the note was created';
COMMENT ON COLUMN dwh.facts.opened_dimension_id_hour_of_week IS
  'Hour of the week when the note was created';
COMMENT ON COLUMN dwh.facts.opened_dimension_id_user IS
  'User who created the note. It could be annonymous';
COMMENT ON COLUMN dwh.facts.closed_dimension_id_date IS
  'Date when the note was closed';
COMMENT ON COLUMN dwh.facts.closed_dimension_id_hour_of_week IS
  'Hour of the week when the note was closed';
COMMENT ON COLUMN dwh.facts.closed_dimension_id_user IS
  'User who created the note';
COMMENT ON COLUMN dwh.facts.dimension_application_creation IS
  'Application used to create the note. Only for opened actions';
COMMENT ON COLUMN dwh.facts.recent_opened_dimension_id_date IS
  'Open date or most recent reopen date';
COMMENT ON COLUMN dwh.facts.days_to_resolution IS
  'Number of days between opening and most recent close';
COMMENT ON COLUMN dwh.facts.days_to_resolution_active IS
  'Number of days open - including only reopens';
COMMENT ON COLUMN dwh.facts.days_to_resolution_from_reopen IS
  'Number of days between last reopening and most recent close';
COMMENT ON COLUMN dwh.facts.hashtag_1 IS
  'First hashtag of the comment';
COMMENT ON COLUMN dwh.facts.hashtag_2 IS
  'Second hashtag of the comment';
COMMENT ON COLUMN dwh.facts.hashtag_3 IS
  'Third hashtag of the comment';
COMMENT ON COLUMN dwh.facts.hashtag_4 IS
  'Fourth hashtag of the comment';
COMMENT ON COLUMN dwh.facts.hashtag_5 IS
  'Fifth hashtag of the comment';
COMMENT ON COLUMN dwh.facts.hashtag_number IS
  'Number of hashtags in the note';

CREATE TABLE IF NOT EXISTS dwh.dimension_users (
 dimension_user_id SERIAL,
 user_id INTEGER NOT NULL,
 username VARCHAR(256),
 modified BOOLEAN
);
COMMENT ON TABLE dwh.dimension_users IS 'Dimension for users';
COMMENT ON COLUMN dwh.dimension_users.dimension_user_id IS 'Surrogated ID';
COMMENT ON COLUMN dwh.dimension_users.user_id IS 'OSM User ir';
COMMENT ON COLUMN dwh.dimension_users.username IS
  'Username at the moment of the last note';
COMMENT ON COLUMN dwh.dimension_users.modified IS
  'Flag to mark users that have performed note actions';

CREATE TABLE IF NOT EXISTS dwh.dimension_regions (
 dimension_region_id SERIAL,
 region_name_es VARCHAR(60),
 region_name_en VARCHAR(60)
);
COMMENT ON TABLE dwh.dimension_regions IS 'Regions for contries';
COMMENT ON COLUMN dwh.dimension_regions.dimension_region_id IS 'Id';
COMMENT ON COLUMN dwh.dimension_regions.region_name_es IS
  'Name of the region in Spanish';
COMMENT ON COLUMN dwh.dimension_regions.region_name_en IS
  'Name of the region in English';

CREATE TABLE IF NOT EXISTS dwh.dimension_countries (
 dimension_country_id SERIAL,
 country_id INTEGER NOT NULL,
 country_name VARCHAR(100),
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100),
 region_id INTEGER,
 modified BOOLEAN
);
COMMENT ON TABLE dwh.dimension_countries IS 'Dimension for contries';
COMMENT ON COLUMN dwh.dimension_countries.dimension_country_id IS
  'Surrogated ID';
COMMENT ON COLUMN dwh.dimension_countries.country_id IS
  'OSM Contry relation ID';
COMMENT ON COLUMN dwh.dimension_countries.country_name IS
  'Name in local language';
COMMENT ON COLUMN dwh.dimension_countries.country_name_es IS 'Name in English';
COMMENT ON COLUMN dwh.dimension_countries.country_name_en IS 'Name in Spanish';
COMMENT ON COLUMN dwh.dimension_countries.modified IS
 'Flag to mark countries that have note actions on them';

CREATE TABLE IF NOT EXISTS dwh.dimension_days (
 dimension_day_id SERIAL,
 date_id DATE,
 year SMALLINT,
 month SMALLINT,
 day SMALLINT
);
COMMENT ON TABLE dwh.dimension_days IS 'Dimension for days';
COMMENT ON COLUMN dwh.dimension_days.dimension_day_id IS 'Surrogated ID';
COMMENT ON COLUMN dwh.dimension_days.date_id IS 'Complete date';
COMMENT ON COLUMN dwh.dimension_days.year IS 'Year of the date';
COMMENT ON COLUMN dwh.dimension_days.month IS 'Month of the date';
COMMENT ON COLUMN dwh.dimension_days.day IS 'Day of date';

CREATE TABLE IF NOT EXISTS dwh.dimension_hours_of_week (
 dimension_how_id SMALLINT,
 day_of_week SMALLINT,
 hour_of_day SMALLINT
);
COMMENT ON TABLE dwh.dimension_hours_of_week IS
  'Dimension for hours of the week';
COMMENT ON COLUMN dwh.dimension_hours_of_week.dimension_how_id IS
  'Hour of week identifier: dayOfWeek-hourOfDay';
COMMENT ON COLUMN dwh.dimension_hours_of_week.day_of_week IS 'Day of the week';
COMMENT ON COLUMN dwh.dimension_hours_of_week.hour_of_day IS 'Hour of the day';

CREATE TABLE IF NOT EXISTS dwh.dimension_applications (
 dimension_application_id SERIAL,
 application_name VARCHAR(64) NOT NULL,
 pattern VARCHAR(64),
 platform VARCHAR(16)
);
COMMENT ON TABLE dwh.dimension_applications IS
  'Dimension for applications creating notes';
COMMENT ON COLUMN dwh.dimension_applications.dimension_application_id IS
  'Surrogated ID';
COMMENT ON COLUMN dwh.dimension_applications.application_name IS
  'Complete name of the application';
COMMENT ON COLUMN dwh.dimension_applications.pattern IS
  'Pattern to find in the comment''text with a SIMILAR TO predicate';
COMMENT ON COLUMN dwh.dimension_applications.platform IS
  'Platform of the appLication';

CREATE TABLE IF NOT EXISTS dwh.dimension_hashtags (
 dimension_hashtag_id SERIAL,
 description TEXT
);
COMMENT ON TABLE dwh.dimension_hashtags IS
  'Dimension for hashtags';
COMMENT ON COLUMN dwh.dimension_hashtags.dimension_hashtag_id IS
  'Surrogated ID';
COMMENT ON COLUMN dwh.dimension_hashtags.description IS
  'Description of the hashtag, only for popular ones';

CREATE TABLE IF NOT EXISTS dwh.properties (
 key VARCHAR(16),
 value VARCHAR(26)
);
COMMENT ON TABLE dwh.properties IS 'Properties table for ETL';
COMMENT ON COLUMN dwh.properties.key IS 'Property name';
COMMENT ON COLUMN dwh.properties.value IS 'Property value';

