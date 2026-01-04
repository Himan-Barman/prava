import { IsBoolean, IsInt, IsNumber, IsOptional, IsString } from 'class-validator';

export class UpdateUserSettingsDto {
  @IsOptional()
  @IsBoolean()
  privateAccount?: boolean;

  @IsOptional()
  @IsBoolean()
  activityStatus?: boolean;

  @IsOptional()
  @IsBoolean()
  readReceipts?: boolean;

  @IsOptional()
  @IsBoolean()
  messagePreview?: boolean;

  @IsOptional()
  @IsBoolean()
  sensitiveContent?: boolean;

  @IsOptional()
  @IsBoolean()
  locationSharing?: boolean;

  @IsOptional()
  @IsBoolean()
  twoFactor?: boolean;

  @IsOptional()
  @IsBoolean()
  loginAlerts?: boolean;

  @IsOptional()
  @IsBoolean()
  appLock?: boolean;

  @IsOptional()
  @IsBoolean()
  biometrics?: boolean;

  @IsOptional()
  @IsBoolean()
  pushNotifications?: boolean;

  @IsOptional()
  @IsBoolean()
  emailNotifications?: boolean;

  @IsOptional()
  @IsBoolean()
  inAppSounds?: boolean;

  @IsOptional()
  @IsBoolean()
  inAppHaptics?: boolean;

  @IsOptional()
  @IsBoolean()
  dataSaver?: boolean;

  @IsOptional()
  @IsBoolean()
  autoDownload?: boolean;

  @IsOptional()
  @IsBoolean()
  autoPlayVideos?: boolean;

  @IsOptional()
  @IsBoolean()
  reduceMotion?: boolean;

  @IsOptional()
  @IsInt()
  themeIndex?: number;

  @IsOptional()
  @IsNumber()
  textScale?: number;

  @IsOptional()
  @IsString()
  languageLabel?: string;
}
