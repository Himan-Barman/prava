import { IsString, MaxLength, MinLength } from 'class-validator';

export class RevokePushTokenDto {
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  deviceId!: string;
}
