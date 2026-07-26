-- AlterTable
ALTER TABLE "event_members"
ADD COLUMN "live_activity_token" VARCHAR(512);

-- CreateIndex
CREATE INDEX "event_members_event_id_live_activity_token_idx"
ON "event_members"("event_id", "live_activity_token");
