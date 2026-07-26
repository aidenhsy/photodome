import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';
import type { HostTransferGrant } from '../../domain/event';

export class CreateHostTransferResponseDto {
  @ApiProperty({
    example: 'pdt_OpaqueOneTimeTransferToken',
    writeOnly: true,
  })
  transferToken!: string;

  @ApiProperty({ example: '2026-07-25T00:10:00.000Z' })
  expiresAt!: string;

  static fromDomain(
    transfer: HostTransferGrant,
  ): CreateHostTransferResponseDto {
    return {
      transferToken: transfer.transferToken,
      expiresAt: transfer.expiresAt.toISOString(),
    };
  }
}

export class ExchangeHostTransferDto {
  @ApiProperty({ example: 'pdt_OpaqueOneTimeTransferToken' })
  @IsString()
  @Matches(/^pdt_[A-Za-z0-9_-]{43}$/)
  transferToken!: string;
}
