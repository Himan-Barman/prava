import { IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class SignedPreKeyDto {
  @IsInt()
  @Min(0)
  keyId!: number;

  @IsString()
  @MaxLength(2048)
  publicKey!: string;

  @IsString()
  @MaxLength(4096)
  signature!: string;

  @IsOptional()
  @IsString()
  expiresAt?: string;
}
