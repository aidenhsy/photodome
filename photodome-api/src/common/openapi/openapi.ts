import type { INestApplication } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import type { OpenAPIObject } from '@nestjs/swagger';

export function createOpenAPIDocument(app: INestApplication): OpenAPIObject {
  const config = new DocumentBuilder()
    .setTitle('PhotoDome API')
    .setDescription('Backend API for the PhotoDome iPhone app.')
    .setVersion('0.1.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'event capability',
        description: 'Opaque event-scoped host or guest capability.',
      },
      'eventCapability',
    )
    .build();

  return SwaggerModule.createDocument(app, config);
}

export function mountOpenAPI(app: INestApplication): void {
  const document = createOpenAPIDocument(app);
  SwaggerModule.setup('api', app, document, {
    jsonDocumentUrl: 'api-json',
  });
}
