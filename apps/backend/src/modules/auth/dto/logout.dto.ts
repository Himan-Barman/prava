import { IsUUID, IsString } from 'class-validator';

export class LogoutDto {
  @IsUUID()
  userId!: string;

  @IsString()
  deviceId!: string;
}
