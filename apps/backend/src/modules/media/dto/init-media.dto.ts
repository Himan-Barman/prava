import {
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

const MAX_MEDIA_BYTES = 100 * 1024 * 1024;

export class InitMediaDto {
  @IsUUID()
  conversationId!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(128)
  contentType!: string;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  fileName?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(MAX_MEDIA_BYTES)
  sizeBytes?: number;

  @IsOptional()
  @IsString()
  @MinLength(64)
  @MaxLength(64)
  sha256?: string;

  @IsOptional()
  @IsIn(['standard', 'ephemeral'])
  retentionPolicy?: 'standard' | 'ephemeral';

  @IsOptional()
  @IsString()
  @MaxLength(32)
  encryptionAlgorithm?: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  encryptionKeyId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  encryptionIv?: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  encryptionKeyHash?: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}
