-- CreateEnum
CREATE TYPE "EventState" AS ENUM ('LIVE', 'ENDED', 'EXPIRING');

-- CreateEnum
CREATE TYPE "EventMemberRole" AS ENUM ('HOST', 'GUEST');

-- CreateTable
CREATE TABLE "events" (
    "id" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "cover_photo_id" UUID,
    "location_label" VARCHAR(160),
    "state" "EventState" NOT NULL DEFAULT 'LIVE',
    "join_code_hash" CHAR(64) NOT NULL,
    "uploads_restricted_at" TIMESTAMPTZ(3),
    "ended_at" TIMESTAMPTZ(3),
    "expires_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_members" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "role" "EventMemberRole" NOT NULL,
    "capability_hash" CHAR(64) NOT NULL,
    "removed_at" TIMESTAMPTZ(3),
    "joined_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "host_transfer_tokens" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "token_hash" CHAR(64) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "consumed_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "host_transfer_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "events_join_code_hash_key" ON "events"("join_code_hash");

-- CreateIndex
CREATE UNIQUE INDEX "event_members_capability_hash_key" ON "event_members"("capability_hash");

-- CreateIndex
CREATE INDEX "event_members_event_id_removed_at_idx" ON "event_members"("event_id", "removed_at");

-- CreateIndex
CREATE INDEX "event_members_event_id_role_idx" ON "event_members"("event_id", "role");

-- CreateIndex
CREATE UNIQUE INDEX "host_transfer_tokens_token_hash_key" ON "host_transfer_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "host_transfer_tokens_event_id_consumed_at_idx" ON "host_transfer_tokens"("event_id", "consumed_at");

-- AddForeignKey
ALTER TABLE "event_members" ADD CONSTRAINT "event_members_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "host_transfer_tokens" ADD CONSTRAINT "host_transfer_tokens_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
