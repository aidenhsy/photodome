import { Module } from '@nestjs/common';
import { CAPABILITY_CODEC } from './domain/capability';
import { HmacCapabilityCodec } from './infrastructure/hmac-capability-codec';

@Module({
  providers: [
    {
      provide: CAPABILITY_CODEC,
      useClass: HmacCapabilityCodec,
    },
  ],
  exports: [CAPABILITY_CODEC],
})
export class CapabilitiesModule {}
