CREATE TABLE "event_cleanup_tombstones" (
    "event_id" UUID NOT NULL,
    "prefix" VARCHAR(300) NOT NULL,
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "last_error" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_attempt_at" TIMESTAMPTZ(3),

    CONSTRAINT "event_cleanup_tombstones_pkey" PRIMARY KEY ("event_id")
);

CREATE UNIQUE INDEX "event_cleanup_tombstones_prefix_key"
ON "event_cleanup_tombstones"("prefix");

CREATE INDEX "event_cleanup_tombstones_created_at_idx"
ON "event_cleanup_tombstones"("created_at");
