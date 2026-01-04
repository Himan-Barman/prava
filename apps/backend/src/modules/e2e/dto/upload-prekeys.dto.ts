import {
  ArrayMaxSize,
  IsArray,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { PreKeyDto } from './prekey.dto';

export class UploadPreKeysDto {
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  deviceId!: string;

  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => PreKeyDto)
  preKeys!: PreKeyDto[];
}
