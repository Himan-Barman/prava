import { IsString, MinLength, MaxLength } from 'class-validator';

export class DeviceDto {
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  deviceId!: string;
}
