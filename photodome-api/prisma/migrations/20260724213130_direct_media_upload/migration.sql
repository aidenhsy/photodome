-- CreateEnum
CREATE TYPE "PhotoState" AS ENUM ('RESERVED', 'PROCESSING', 'READY', 'FAILED', 'REMOVED', 'EXPIRED');

-- CreateTable
CREATE TABLE "photos" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "contributor_member_id" UUID NOT NULL,
    "state" "PhotoState" NOT NULL DEFAULT 'RESERVED',
    "original_key" VARCHAR(300) NOT NULL,
    "display_key" VARCHAR(300) NOT NULL,
    "thumb_key" VARCHAR(300) NOT NULL,
    "content_type" VARCHAR(80) NOT NULL,
    "byte_size" INTEGER NOT NULL,
    "sha256" CHAR(64) NOT NULL,
    "width" INTEGER NOT NULL,
    "height" INTEGER NOT NULL,
    "captured_at" TIMESTAMPTZ(3),
    "orientation" INTEGER NOT NULL DEFAULT 1,
    "admitted_before_restriction" BOOLEAN NOT NULL,
    "reserved_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "uploaded_at" TIMESTAMPTZ(3),
    "ready_at" TIMESTAMPTZ(3),
    "failure_reason" VARCHAR(160),

    CONSTRAINT "photos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "photos_original_key_key" ON "photos"("original_key");

-- CreateIndex
CREATE UNIQUE INDEX "photos_display_key_key" ON "photos"("display_key");

-- CreateIndex
CREATE UNIQUE INDEX "photos_thumb_key_key" ON "photos"("thumb_key");

-- CreateIndex
CREATE INDEX "photos_event_id_state_ready_at_idx" ON "photos"("event_id", "state", "ready_at");

-- CreateIndex
CREATE INDEX "photos_contributor_member_id_state_idx" ON "photos"("contributor_member_id", "state");

-- AddForeignKey
ALTER TABLE "photos" ADD CONSTRAINT "photos_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "photos" ADD CONSTRAINT "photos_contributor_member_id_fkey" FOREIGN KEY ("contributor_member_id") REFERENCES "event_members"("id") ON DELETE CASCADE ON UPDATE CASCADE;
