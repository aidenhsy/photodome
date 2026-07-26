import { ConfigService } from '@nestjs/config';
import type { Environment } from '../../../common/config/env.validation';
import { HmacCapabilityCodec } from './hmac-capability-codec';

describe('HmacCapabilityCodec', () => {
  const codec = new HmacCapabilityCodec(
    new ConfigService<Environment, true>({
      CAPABILITY_PEPPER: 'unit-test-capability-pepper-at-least-32-characters',
    }),
  );

  it('generates high-entropy event and transfer capabilities', () => {
    expect(codec.generateEventCapability()).toMatch(/^pdc_[A-Za-z0-9_-]{43}$/);
    expect(codec.generateTransferToken()).toMatch(/^pdt_[A-Za-z0-9_-]{43}$/);
  });

  it('normalizes human join codes without ambiguous punctuation', () => {
    const code = codec.generateJoinCode();

    expect(code).toMatch(/^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{8}$/);
    expect(
      codec.normalizeJoinCode(` ${code.slice(0, 4)}-${code.slice(4)} `),
    ).toBe(code);
  });

  it('uses purpose-separated hashes and constant-time verification', () => {
    const capability = 'pdc_test-value';
    const capabilityHash = codec.hashCapability(capability);

    expect(capabilityHash).not.toBe(codec.hashTransferToken(capability));
    expect(codec.matchesHash(capabilityHash, capabilityHash)).toBe(true);
    expect(
      codec.matchesHash(codec.hashCapability('different'), capabilityHash),
    ).toBe(false);
  });
});
