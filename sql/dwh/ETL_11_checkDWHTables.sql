-- Check data warehouse tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-02

  DO /* Notes-ETL-checkTables */
  $$
  DECLARE
   qty INT;
  BEGIN

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'facts'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.facts.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_users'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_users.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_regions'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_regions.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_countries'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_countries.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_days'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_days.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_hours_of_week'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_hours_of_week.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_applications'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_applications.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_hashtags'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_hashtags.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'properties'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.properties.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(1)
    INTO qty
   FROM dwh.properties
   WHERE key = 'initial load'
   AND value = 'true'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Previous initial load was not complete correctly.';
   END IF;
  END;
  $$;
