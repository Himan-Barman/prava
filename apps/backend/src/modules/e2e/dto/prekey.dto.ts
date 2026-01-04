import { IsInt, IsString, MaxLength, Min } from 'class-validator';

export class PreKeyDto {
  @IsInt()
  @Min(0)
  keyId!: number;

  @IsString()
  @MaxLength(2048)
  publicKey!: string;
}
