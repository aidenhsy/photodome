import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/common/bootstrap/configure-app';

describe('Health API (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = module.createNestApplication();
    configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /v1/health', async () => {
    const server = app.getHttpServer() as Server;
    const response = await request(server).get('/v1/health').expect(200);
    const body = response.body as {
      status: unknown;
      service: unknown;
      version: unknown;
      timestamp: unknown;
    };

    expect(body).toMatchObject({
      status: 'ok',
      service: 'photodome-api',
      version: '0.1.0',
    });
    expect(body.timestamp).toEqual(expect.any(String));
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['x-frame-options']).toBe('DENY');
    expect(response.headers['referrer-policy']).toBe('no-referrer');
    expect(response.headers['permissions-policy']).toBe(
      'camera=(), microphone=(), geolocation=()',
    );
  });

  it('GET /v1/health/ready', async () => {
    const server = app.getHttpServer() as Server;
    const response = await request(server).get('/v1/health/ready').expect(200);

    expect(response.body).toMatchObject({
      status: 'ready',
      service: 'photodome-api',
      dependencies: {
        postgres: 'ok',
        redis: 'ok',
      },
    });
  });
});
