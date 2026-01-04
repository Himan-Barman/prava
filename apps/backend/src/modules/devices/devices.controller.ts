import {
  Body,
  Controller,
  Delete,
  Post,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '@/common/guards/jwt.guard';
import { CurrentUser } from '@/common/decorators/user.decorator';
import { JwtPayload } from '@/common/types/jwt-payload';
import { DevicesService } from './devices.service';
import { RegisterPushTokenDto } from './dto/register-push-token.dto';
import { RevokePushTokenDto } from './dto/revoke-push-token.dto';

@UseGuards(JwtAuthGuard)
@Controller('devices')
export class DevicesController {
  constructor(private readonly devices: DevicesService) {}

  @Post('push-token')
  registerPushToken(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RegisterPushTokenDto,
  ) {
    return this.devices.registerPushToken({
      userId: user.sub,
      deviceId: dto.deviceId,
      platform: dto.platform,
      token: dto.token,
    });
  }

  @Delete('push-token')
  revokePushToken(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RevokePushTokenDto,
  ) {
    return this.devices.revokePushToken({
      userId: user.sub,
      deviceId: dto.deviceId,
    });
  }
}
