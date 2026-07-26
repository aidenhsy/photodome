import { spawnSync } from 'node:child_process';
import { Client } from 'pg';

const DATABASE_NAME = 'photodome_test';
const adminUrl =
  process.env.TEST_DATABASE_ADMIN_URL ??
  'postgresql://photodome:photodome@localhost:5434/postgres';
const testDatabaseUrl =
  process.env.TEST_DATABASE_URL ??
  `postgresql://photodome:photodome@localhost:5434/${DATABASE_NAME}?schema=public`;

async function prepare(): Promise<void> {
  const client = new Client({ connectionString: adminUrl });

  try {
    await client.connect();
  } catch {
    throw new Error(
      'PostgreSQL is unavailable. Run `docker compose up -d postgres` first.',
    );
  }

  const existing = await client.query<{ exists: boolean }>(
    'SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1) AS "exists"',
    [DATABASE_NAME],
  );

  if (!existing.rows[0]?.exists) {
    await client.query(`CREATE DATABASE ${DATABASE_NAME}`);
  }
  await client.end();

  const migration = spawnSync('npx', ['prisma', 'migrate', 'deploy'], {
    cwd: process.cwd(),
    env: { ...process.env, DATABASE_URL: testDatabaseUrl },
    encoding: 'utf8',
  });

  if (migration.status !== 0) {
    process.stderr.write(migration.stderr);
    throw new Error('Could not apply Prisma migrations to the test database.');
  }
}

void prepare().catch((error: unknown) => {
  process.stderr.write(
    `${error instanceof Error ? error.message : String(error)}\n`,
  );
  process.exitCode = 1;
});
