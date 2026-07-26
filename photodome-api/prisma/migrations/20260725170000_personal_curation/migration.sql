CREATE TYPE "PhotoSelectionDecision" AS ENUM ('KEEP', 'SKIP');

CREATE TABLE "photo_selections" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "member_id" UUID NOT NULL,
    "photo_id" UUID NOT NULL,
    "decision" "PhotoSelectionDecision" NOT NULL,
    "decided_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "photo_selections_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "photo_selections_member_id_photo_id_key"
ON "photo_selections"("member_id", "photo_id");

CREATE INDEX "photo_selections_event_id_member_id_decided_at_idx"
ON "photo_selections"("event_id", "member_id", "decided_at");

CREATE INDEX "photo_selections_member_id_decision_idx"
ON "photo_selections"("member_id", "decision");

ALTER TABLE "photo_selections"
ADD CONSTRAINT "photo_selections_event_id_fkey"
FOREIGN KEY ("event_id") REFERENCES "events"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "photo_selections"
ADD CONSTRAINT "photo_selections_member_id_fkey"
FOREIGN KEY ("member_id") REFERENCES "event_members"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "photo_selections"
ADD CONSTRAINT "photo_selections_photo_id_fkey"
FOREIGN KEY ("photo_id") REFERENCES "photos"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
