import { IsString, MinLength } from 'class-validator';

export class RefreshDto {
  @IsString()
  @MinLength(20)
  refreshToken!: string;

  @IsString()
  @MinLength(10)
  deviceId!: string;
}
