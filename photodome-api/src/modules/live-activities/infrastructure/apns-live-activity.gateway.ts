import { Injectable, Logger, type OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createPrivateKey, createSign } from 'node:crypto';
import http2 from 'node:http2';
import type { Environment } from '../../../common/config/env.validation';
import type {
  ApnsLiveActivityGateway,
  LiveActivityPushResult,
} from '../application/ports/apns-live-activity.gateway';

const APNS_HOSTS = {
  production: 'https://api.push.apple.com',
  sandbox: 'https://api.sandbox.push.apple.com',
} as const;

@Injectable()
export class ApnsHttp2LiveActivityGateway
  implements ApnsLiveActivityGateway, OnModuleDestroy
{
  private readonly logger = new Logger(ApnsHttp2LiveActivityGateway.name);
  private readonly bundleId?: string;
  private readonly teamId?: string;
  private readonly keyId?: string;
  private readonly privateKey?: string;
  private readonly session: http2.ClientHttp2Session | null;
  private cachedProviderToken: { value: string; expiresAt: number } | null =
    null;

  constructor(config: ConfigService<Environment, true>) {
    this.bundleId = config.get('APNS_BUNDLE_ID', { infer: true });
    this.teamId = config.get('APNS_TEAM_ID', { infer: true });
    this.keyId = config.get('APNS_KEY_ID', { infer: true });
    this.privateKey = config.get('APNS_PRIVATE_KEY', { infer: true });

    if (this.isConfigured()) {
      const environment = config.get('APNS_ENVIRONMENT', { infer: true });
      this.session = http2.connect(APNS_HOSTS[environment]);
      this.session.on('error', (error) => {
        this.logger.error('APNs HTTP/2 session error', error);
      });
    } else {
      this.session = null;
      this.logger.warn(
        'APNs credentials are not configured; remote Live Activity updates are disabled.',
      );
    }
  }

  async update(
    pushToken: string,
    contentState: Record<string, unknown>,
  ): Promise<LiveActivityPushResult> {
    return this.send(pushToken, 'update', contentState);
  }

  async end(
    pushToken: string,
    contentState: Record<string, unknown>,
  ): Promise<LiveActivityPushResult> {
    return this.send(pushToken, 'end', contentState);
  }

  private async send(
    pushToken: string,
    event: 'update' | 'end',
    contentState: Record<string, unknown>,
  ): Promise<LiveActivityPushResult> {
    if (!this.session || !this.isConfigured()) {
      return { invalid: false };
    }

    const providerToken = this.providerToken();
    const payload = {
      aps: {
        timestamp: Math.floor(Date.now() / 1_000),
        event,
        'content-state': contentState,
        ...(event === 'end'
          ? { 'dismissal-date': Math.floor(Date.now() / 1_000) }
          : {}),
      },
    };

    return new Promise((resolve) => {
      const request = this.session!.request({
        ':method': 'POST',
        ':path': `/3/device/${pushToken}`,
        authorization: `bearer ${providerToken}`,
        'apns-topic': `${this.bundleId!}.push-type.liveactivity`,
        'apns-push-type': 'liveactivity',
        'apns-priority': '10',
        'content-type': 'application/json',
      });
      let status = 0;
      let body = '';
      let settled = false;
      const finish = (result: LiveActivityPushResult): void => {
        if (settled) return;
        settled = true;
        resolve(result);
      };

      request.setTimeout(10_000, () => {
        request.close();
        finish({ invalid: false, error: 'APNs request timed out' });
      });
      request.on('response', (headers) => {
        status = Number(headers[':status'] ?? 0);
      });
      request.on('data', (chunk: Buffer) => {
        body += chunk.toString();
      });
      request.on('error', (error: Error) => {
        finish({ invalid: false, error: error.message });
      });
      request.on('end', () => {
        if (status === 200) {
          finish({ invalid: false });
          return;
        }
        const invalid =
          status === 410 || /BadDeviceToken|Unregistered/i.test(body);
        finish({
          invalid,
          error: body || `APNs returned HTTP ${status}`,
        });
      });
      request.end(JSON.stringify(payload));
    });
  }

  async onModuleDestroy(): Promise<void> {
    if (!this.session) {
      return;
    }
    await new Promise<void>((resolve) => this.session!.close(resolve));
  }

  private isConfigured(): boolean {
    return Boolean(
      this.bundleId && this.teamId && this.keyId && this.privateKey,
    );
  }

  private providerToken(): string {
    const now = Math.floor(Date.now() / 1_000);
    if (
      this.cachedProviderToken &&
      this.cachedProviderToken.expiresAt > now + 60
    ) {
      return this.cachedProviderToken.value;
    }

    const encodedHeader = Buffer.from(
      JSON.stringify({ alg: 'ES256', kid: this.keyId }),
    ).toString('base64url');
    const encodedClaims = Buffer.from(
      JSON.stringify({ iss: this.teamId, iat: now }),
    ).toString('base64url');
    const signingInput = `${encodedHeader}.${encodedClaims}`;
    const signer = createSign('SHA256');
    signer.update(signingInput);
    signer.end();
    const signature = signer.sign({
      key: createPrivateKey(this.privateKey!),
      dsaEncoding: 'ieee-p1363',
    });
    const value = `${signingInput}.${signature.toString('base64url')}`;
    this.cachedProviderToken = {
      value,
      expiresAt: now + 50 * 60,
    };
    return value;
  }
}
