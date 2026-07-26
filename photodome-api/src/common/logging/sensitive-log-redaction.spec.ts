import { Writable } from 'node:stream';
import pino from 'pino';
import { SENSITIVE_LOG_PATHS } from './sensitive-log-redaction';

describe('sensitive log redaction', () => {
  it('censors event authority, media sessions, and signed reads', () => {
    const output: string[] = [];
    const destination = new Writable({
      write(chunk: Buffer, _encoding, callback) {
        output.push(chunk.toString());
        callback();
      },
    });
    const logger = pino(
      {
        redact: {
          paths: [...SENSITIVE_LOG_PATHS],
          censor: '[REDACTED]',
        },
      },
      destination,
    );
    const secrets = {
      capability: 'pdc_capability-secret',
      joinCode: 'ABC123',
      transferToken: 'pdt_transfer-secret',
      pushToken: 'activity-token-secret',
      sessionUri: 'https://storage.example/resumable-secret',
      originalUrl: 'https://storage.example/original?signature=secret',
    };

    logger.info({
      ...secrets,
      req: {
        headers: {
          authorization: `Bearer ${secrets.capability}`,
          cookie: 'secret-cookie',
          'x-photodome-installation-id': 'secret-installation',
        },
        body: secrets,
      },
      nested: secrets,
    });

    const serialized = output.join('');
    for (const secret of [
      ...Object.values(secrets),
      'secret-cookie',
      'secret-installation',
    ]) {
      expect(serialized).not.toContain(secret);
    }
    expect(serialized).toContain('[REDACTED]');
  });
});
