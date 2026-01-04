import {
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { SignedPreKeyDto } from './signed-prekey.dto';

export class RotateSignedPreKeyDto {
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  deviceId!: string;

  @ValidateNested()
  @Type(() => SignedPreKeyDto)
  signedPreKey!: SignedPreKeyDto;
}
