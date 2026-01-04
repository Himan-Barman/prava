import { IsIn, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class TrustDeviceDto {
  @IsUUID()
  targetUserId!: string;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  targetDeviceId!: string;

  @IsString()
  @IsIn(['trusted', 'unverified', 'blocked'])
  status!: 'trusted' | 'unverified' | 'blocked';
}
