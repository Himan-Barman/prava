import { Type } from 'class-transformer';
import { IsInt, IsString, Max, Min, MaxLength, MinLength } from 'class-validator';

export class ReadReceiptDto {
  @IsInt()
  @Min(0)
  @Max(1_000_000_000)
  @Type(() => Number)
  lastReadSeq!: number;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  deviceId!: string;
}
