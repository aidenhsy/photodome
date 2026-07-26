ALTER TABLE "photos"
ADD COLUMN "removed_at" TIMESTAMPTZ(3);

CREATE TABLE "photo_deletion_tombstones" (
    "id" UUID NOT NULL,
    "photo_id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "original_key" VARCHAR(300) NOT NULL,
    "display_key" VARCHAR(300) NOT NULL,
    "thumb_key" VARCHAR(300) NOT NULL,
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "last_error" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_attempt_at" TIMESTAMPTZ(3),

    CONSTRAINT "photo_deletion_tombstones_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "photo_deletion_tombstones_photo_id_key"
ON "photo_deletion_tombstones"("photo_id");

CREATE INDEX "photo_deletion_tombstones_event_id_idx"
ON "photo_deletion_tombstones"("event_id");

ALTER TABLE "photo_deletion_tombstones"
ADD CONSTRAINT "photo_deletion_tombstones_photo_id_fkey"
FOREIGN KEY ("photo_id") REFERENCES "photos"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "photo_deletion_tombstones"
ADD CONSTRAINT "photo_deletion_tombstones_event_id_fkey"
FOREIGN KEY ("event_id") REFERENCES "events"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
