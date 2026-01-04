import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '@/common/guards/jwt.guard';
import { CurrentUser } from '@/common/decorators/user.decorator';
import { JwtPayload } from '@/common/types/jwt-payload';
import { RegisterDeviceKeysDto } from './dto/register-device-keys.dto';
import { UploadPreKeysDto } from './dto/upload-prekeys.dto';
import { RotateSignedPreKeyDto } from './dto/rotate-signed-prekey.dto';
import { TrustDeviceDto } from './dto/trust-device.dto';
import { E2eService } from './e2e.service';

@UseGuards(JwtAuthGuard)
@Controller('crypto')
export class E2eController {
  constructor(private readonly e2e: E2eService) {}

  @Post('devices/register')
  registerDevice(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RegisterDeviceKeysDto,
  ) {
    return this.e2e.registerDeviceKeys({
      userId: user.sub,
      deviceId: dto.deviceId,
      platform: dto.platform,
      deviceName: dto.deviceName,
      identityKey: dto.identityKey,
      registrationId: dto.registrationId,
      signedPreKey: dto.signedPreKey,
      oneTimePreKeys: dto.oneTimePreKeys,
    });
  }

  @Post('prekeys')
  uploadPreKeys(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UploadPreKeysDto,
  ) {
    return this.e2e.uploadPreKeys({
      userId: user.sub,
      deviceId: dto.deviceId,
      preKeys: dto.preKeys,
    });
  }

  @Post('signed-prekey')
  rotateSignedPreKey(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RotateSignedPreKeyDto,
  ) {
    return this.e2e.rotateSignedPreKey({
      userId: user.sub,
      deviceId: dto.deviceId,
      signedPreKey: dto.signedPreKey,
    });
  }

  @Get('devices/:userId')
  listDevices(
    @CurrentUser() user: JwtPayload,
    @Param('userId') userId: string,
  ) {
    return this.e2e.listDevicesForUser({
      requesterId: user.sub,
      targetUserId: userId,
    });
  }

  @Get('bundle/:userId/:deviceId')
  getBundle(
    @CurrentUser() user: JwtPayload,
    @Param('userId') userId: string,
    @Param('deviceId') deviceId: string,
  ) {
    return this.e2e.getPreKeyBundle({
      requesterId: user.sub,
      targetUserId: userId,
      targetDeviceId: deviceId,
    });
  }

  @Post('trust')
  trustDevice(
    @CurrentUser() user: JwtPayload,
    @Body() dto: TrustDeviceDto,
  ) {
    return this.e2e.setTrust({
      requesterId: user.sub,
      targetUserId: dto.targetUserId,
      targetDeviceId: dto.targetDeviceId,
      status: dto.status,
    });
  }

  @Get('trust/:userId')
  listTrust(
    @CurrentUser() user: JwtPayload,
    @Param('userId') userId: string,
  ) {
    return this.e2e.listTrustForUser({
      requesterId: user.sub,
      targetUserId: userId,
    });
  }
}
