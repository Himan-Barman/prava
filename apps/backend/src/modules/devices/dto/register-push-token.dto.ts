import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterPushTokenDto {
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  deviceId!: string;

  @IsString()
  @IsIn(['android', 'ios', 'web', 'desktop'])
  platform!: 'android' | 'ios' | 'web' | 'desktop';

  @IsString()
  @MinLength(10)
  @MaxLength(512)
  token!: string;
}
