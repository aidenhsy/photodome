import { Logger } from 'nestjs-pino';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import type { Environment } from './common/config/env.validation';
import { configureApp } from './common/bootstrap/configure-app';
import { mountOpenAPI } from './common/openapi/openapi';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.useLogger(app.get(Logger));
  app.enableShutdownHooks();
  configureApp(app);
  mountOpenAPI(app);

  const config = app.get(ConfigService<Environment, true>);
  const port = config.get('PORT', { infer: true });
  await app.listen(port);
}

void bootstrap();
