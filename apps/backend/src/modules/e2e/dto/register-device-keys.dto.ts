import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { PreKeyDto } from './prekey.dto';
import { SignedPreKeyDto } from './signed-prekey.dto';

export class RegisterDeviceKeysDto {
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  deviceId!: string;

  @IsString()
  @IsIn(['android', 'ios', 'web', 'desktop'])
  platform!: 'android' | 'ios' | 'web' | 'desktop';

  @IsOptional()
  @IsString()
  @MaxLength(64)
  deviceName?: string;

  @IsString()
  @MinLength(16)
  @MaxLength(4096)
  identityKey!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  registrationId?: number;

  @ValidateNested()
  @Type(() => SignedPreKeyDto)
  signedPreKey!: SignedPreKeyDto;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => PreKeyDto)
  oneTimePreKeys?: PreKeyDto[];
}
