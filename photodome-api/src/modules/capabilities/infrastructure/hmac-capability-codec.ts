import {
  createHmac,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Environment } from '../../../common/config/env.validation';
import type { CapabilityCodec } from '../domain/capability';

const JOIN_CODE_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const JOIN_CODE_LENGTH = 8;

@Injectable()
export class HmacCapabilityCodec implements CapabilityCodec {
  private readonly pepper: string;

  constructor(config: ConfigService<Environment, true>) {
    this.pepper = config.get('CAPABILITY_PEPPER', { infer: true });
  }

  generateEventCapability(): string {
    return `pdc_${randomBytes(32).toString('base64url')}`;
  }

  generateTransferToken(): string {
    return `pdt_${randomBytes(32).toString('base64url')}`;
  }

  generateJoinCode(): string {
    let code = '';
    for (let index = 0; index < JOIN_CODE_LENGTH; index += 1) {
      code += JOIN_CODE_ALPHABET[randomInt(JOIN_CODE_ALPHABET.length)];
    }
    return code;
  }

  normalizeJoinCode(value: string): string {
    return value.toUpperCase().replace(/[^A-Z0-9]/g, '');
  }

  hashCapability(value: string): string {
    return this.hash('event-capability', value);
  }

  hashTransferToken(value: string): string {
    return this.hash('host-transfer', value);
  }

  hashJoinCode(value: string): string {
    return this.hash('join-code', this.normalizeJoinCode(value));
  }

  matchesHash(candidateHash: string, storedHash: string): boolean {
    const candidate = Buffer.from(candidateHash, 'hex');
    const stored = Buffer.from(storedHash, 'hex');
    return (
      candidate.length === stored.length &&
      candidate.length > 0 &&
      timingSafeEqual(candidate, stored)
    );
  }

  private hash(purpose: string, value: string): string {
    return createHmac('sha256', this.pepper)
      .update(`${purpose}\0${value}`)
      .digest('hex');
  }
}
