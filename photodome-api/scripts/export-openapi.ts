import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import type { Type } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { configureApp } from '../src/common/bootstrap/configure-app';
import { createOpenAPIDocument } from '../src/common/openapi/openapi';

async function exportOpenAPI(): Promise<void> {
  process.env.DISABLE_BACKGROUND_WORKERS = '1';
  // Loaded after the worker flag is set so schema export never starts BullMQ.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const appModuleImport = require('../src/app.module') as {
    AppModule: Type<unknown>;
  };
  const { AppModule } = appModuleImport;
  const output = resolve(process.argv[2] ?? 'openapi.json');
  const app = await NestFactory.create(AppModule, { logger: false });
  configureApp(app);
  const document = createOpenAPIDocument(app);

  writeFileSync(output, `${JSON.stringify(document, null, 2)}\n`);
  await app.close();
  process.stdout.write(`Wrote OpenAPI document to ${output}\n`);
}

void exportOpenAPI();
