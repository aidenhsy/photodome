ALTER TABLE "event_members"
ADD COLUMN "display_name" VARCHAR(50);

UPDATE "event_members"
SET "display_name" = CASE
  WHEN "role" = 'HOST' THEN 'Host'
  ELSE 'Guest'
END;

ALTER TABLE "event_members"
ALTER COLUMN "display_name" SET NOT NULL;

ALTER TABLE "events"
ADD COLUMN "host_display_name" VARCHAR(50);

UPDATE "events"
SET "host_display_name" = COALESCE(
  (
    SELECT "event_members"."display_name"
    FROM "event_members"
    WHERE "event_members"."event_id" = "events"."id"
      AND "event_members"."role" = 'HOST'
    ORDER BY "event_members"."joined_at" ASC
    LIMIT 1
  ),
  'Host'
);

ALTER TABLE "events"
ALTER COLUMN "host_display_name" SET NOT NULL;
