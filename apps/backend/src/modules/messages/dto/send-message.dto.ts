import {
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

import { MAX_MESSAGE_BODY_LENGTH } from '@/common/constants';

export class SendMessageDto {
  @IsOptional()
  @IsString()
  @MaxLength(MAX_MESSAGE_BODY_LENGTH)
  body?: string;

  @IsOptional()
  @IsIn(['text', 'system', 'media'])
  contentType?: 'text' | 'system' | 'media';

  @IsOptional()
  @IsString()
  clientTimestamp?: string;

  @IsOptional()
  @IsString()
  @MinLength(6)
  @MaxLength(64)
  tempId?: string;

  @IsOptional()
  @IsUUID()
  mediaAssetId?: string;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  deviceId!: string;
}
