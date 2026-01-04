import {
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

const MAX_MEDIA_BYTES = 100 * 1024 * 1024;

export class CompleteMediaDto {
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
  @IsObject()
  metadata?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  fileName?: string;
}
