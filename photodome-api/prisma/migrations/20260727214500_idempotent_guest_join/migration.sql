ALTER TABLE "event_members"
ADD COLUMN "join_binding_hash" CHAR(64);

CREATE UNIQUE INDEX "event_members_event_id_join_binding_hash_key"
ON "event_members"("event_id", "join_binding_hash");
