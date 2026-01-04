import { IsString, MinLength, MaxLength } from 'class-validator';

export class CurrentDeviceDto {
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  currentDeviceId!: string;
}
