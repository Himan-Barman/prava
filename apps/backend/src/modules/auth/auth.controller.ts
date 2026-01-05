import {
  Body,
  Controller,
  Post,
  UseGuards,
  Req,
} from '@nestjs/common';
import { FastifyRequest } from 'fastify';

import { AuthService } from './auth.service';
import { RateLimitGuard } from '@/security/rate-limit.guard';
import { JwtAuthGuard } from './jwt.guard';
import { AuthenticatedRequest } from '@/common/types/request-user';

/* DTOs */
import { RegisterDto } from './dto/register.dto';
import { RefreshDto } from './dto/refresh.dto';
import { DeviceDto } from './dto/device.dto';
import { EmailDto } from './dto/email.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { CurrentDeviceDto } from './dto/current-device.dto';
import { LoginDto } from './dto/login.dto';
import { EmailOtpRequestDto } from './dto/email-otp-request.dto';
import { EmailOtpVerifyDto } from './dto/email-otp-verify.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /* ================= REGISTER ================= */

  @UseGuards(RateLimitGuard)
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register({
      email: dto.email,
      password: dto.password,
      username: dto.username,
      deviceId: dto.deviceId,
      deviceName: dto.deviceName,
      platform: dto.platform,
    });
  }

  /* ================= LOGIN ================= */

  @UseGuards(RateLimitGuard)
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login({
      email: dto.email,
      password: dto.password,
      deviceId: dto.deviceId,
      deviceName: dto.deviceName,
      platform: dto.platform,
    });
  }

  /* ================= REFRESH ================= */

  @UseGuards(RateLimitGuard)
  @Post('refresh')
  refresh(@Body() dto: RefreshDto) {
    return this.auth.refresh(dto);
  }

  /* ================= LOGOUT (SINGLE DEVICE) ================= */

  @UseGuards(JwtAuthGuard)
  @Post('logout')
  async logout(
    @Req() req: FastifyRequest & AuthenticatedRequest,
    @Body() dto: DeviceDto
  ) {
    await this.auth.logout(req.user.sub, dto.deviceId);
    return { success: true };
  }

  /* ================= LOGOUT ALL DEVICES ================= */

  @UseGuards(JwtAuthGuard)
  @Post('logout-all')
  async logoutAll(
    @Req() req: FastifyRequest & AuthenticatedRequest
  ) {
    await this.auth.logoutAll(req.user.sub);
    return { success: true };
  }

  /* ================= EMAIL VERIFICATION ================= */

  @UseGuards(RateLimitGuard)
  @Post('verify-email')
  verifyEmail(@Body() dto: { token: string }) {
    return this.auth.verifyEmail(dto.token);
  }

  @UseGuards(RateLimitGuard)
  @Post('verify-email/request')
  requestEmailVerification(@Body() dto: EmailDto) {
    return this.auth.requestEmailVerification(dto.email);
  }

  @UseGuards(RateLimitGuard)
  @Post('verify-email/resend')
  resendEmailVerification(@Body() dto: EmailDto) {
    return this.auth.requestEmailVerification(dto.email);
  }

  /* ================= PASSWORD RESET ================= */

  @UseGuards(RateLimitGuard)
  @Post('password-reset/request')
  requestPasswordReset(@Body() dto: EmailDto) {
    return this.auth.requestPasswordReset(dto.email);
  }

  @UseGuards(RateLimitGuard)
  @Post('password-reset/confirm')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto);
  }

  /* ================= EMAIL OTP (SIGNUP) ================= */

  @UseGuards(RateLimitGuard)
  @Post('email-otp/request')
  requestEmailOtp(@Body() dto: EmailOtpRequestDto) {
    return this.auth.requestEmailOtp(dto.email);
  }

  @UseGuards(RateLimitGuard)
  @Post('email-otp/verify')
  verifyEmailOtp(@Body() dto: EmailOtpVerifyDto) {
    return this.auth.verifyEmailOtp(dto);
  }

  /* ================= SESSIONS ================= */

  @UseGuards(JwtAuthGuard)
  @Post('sessions')
  listSessions(
    @Req() req: FastifyRequest & AuthenticatedRequest
  ) {
    return this.auth.listSessions(req.user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Post('sessions/revoke')
  revokeSession(
    @Req() req: FastifyRequest & AuthenticatedRequest,
    @Body() dto: DeviceDto
  ) {
    return this.auth.revokeSession({
      userId: req.user.sub,
      deviceId: dto.deviceId,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Post('sessions/revoke-others')
  revokeOtherSessions(
    @Req() req: FastifyRequest & AuthenticatedRequest,
    @Body() dto: CurrentDeviceDto
  ) {
    return this.auth.revokeOtherSessions({
      userId: req.user.sub,
      currentDeviceId: dto.currentDeviceId,
    });
  }
}
