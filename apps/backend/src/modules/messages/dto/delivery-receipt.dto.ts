import { Type } from 'class-transformer';
import { IsInt, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';

export class DeliveryReceiptDto {
  @IsInt()
  @Min(0)
  @Max(1_000_000_000)
  @Type(() => Number)
  lastDeliveredSeq!: number;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  deviceId!: string;
}
