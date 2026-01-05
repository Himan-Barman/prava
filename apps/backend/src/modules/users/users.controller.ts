import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '@/common/guards/jwt.guard';
import { CurrentUser } from '@/common/decorators/user.decorator';
import { JwtPayload } from '@/common/types/jwt-payload';
import { UsersService } from './users.service';
import { UpdateUserSettingsDto } from './dto/user-settings.dto';
import { FollowStateDto } from './dto/follow-state.dto';
import { UserDetailsDto } from './dto/user-details.dto';
import { UpdateEmailDto } from './dto/update-email.dto';
import { UpdateHandleDto } from './dto/update-handle.dto';
import { AddMutedWordDto } from './dto/add-muted-word.dto';
import { RateLimitGuard } from '@/security/rate-limit.guard';

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@CurrentUser() user: JwtPayload) {
    return {
      userId: user.sub,
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/account')
  account(@CurrentUser() user: JwtPayload) {
    return this.users.getAccountInfo(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Put('me/email')
  updateEmail(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateEmailDto,
  ) {
    return this.users.updateEmail(user.sub, dto.email);
  }

  @UseGuards(JwtAuthGuard)
  @Put('me/handle')
  updateHandle(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateHandleDto,
  ) {
    return this.users.updateHandle(user.sub, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/settings')
  getSettings(@CurrentUser() user: JwtPayload) {
    return this.users.getSettings(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Put('me/settings')
  updateSettings(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateUserSettingsDto,
  ) {
    return this.users.updateSettings(user.sub, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Put('me/details')
  updateDetails(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UserDetailsDto,
  ) {
    return this.users.updateDetails(user.sub, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/profile')
  profile(
    @CurrentUser() user: JwtPayload,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;

    return this.users.getProfileSummary({
      userId: user.sub,
      limit: parsedLimit,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/blocks')
  blocked(
    @CurrentUser() user: JwtPayload,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;

    return this.users.listBlockedUsers({
      userId: user.sub,
      limit: parsedLimit,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/block')
  block(
    @CurrentUser() user: JwtPayload,
    @Param('id') targetUserId: string,
  ) {
    return this.users.blockUser({
      userId: user.sub,
      targetUserId,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/block')
  unblock(
    @CurrentUser() user: JwtPayload,
    @Param('id') targetUserId: string,
  ) {
    return this.users.unblockUser({
      userId: user.sub,
      targetUserId,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/muted-words')
  mutedWords(
    @CurrentUser() user: JwtPayload,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;

    return this.users.listMutedWords({
      userId: user.sub,
      limit: parsedLimit,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/muted-words')
  addMutedWord(
    @CurrentUser() user: JwtPayload,
    @Body() dto: AddMutedWordDto,
  ) {
    return this.users.addMutedWord({
      userId: user.sub,
      phrase: dto.phrase,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me/muted-words/:id')
  removeMutedWord(
    @CurrentUser() user: JwtPayload,
    @Param('id') wordId: string,
  ) {
    return this.users.removeMutedWord({
      userId: user.sub,
      wordId,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/data-export')
  exportData(@CurrentUser() user: JwtPayload) {
    return this.users.createDataExport(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/data-export')
  latestExport(@CurrentUser() user: JwtPayload) {
    return this.users.getLatestDataExport(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/connections')
  connections(
    @CurrentUser() user: JwtPayload,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;

    return this.users.getConnections({
      userId: user.sub,
      limit: parsedLimit,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me')
  deleteAccount(@CurrentUser() user: JwtPayload) {
    return this.users.deleteAccount(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id/profile')
  publicProfile(
    @CurrentUser() user: JwtPayload,
    @Param('id') targetUserId: string,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;

    return this.users.getPublicProfileSummary({
      targetUserId,
      viewerId: user.sub,
      limit: parsedLimit,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Get('search')
  search(
    @CurrentUser() user: JwtPayload,
    @Query('query') query?: string,
    @Query('limit') limit?: string,
  ) {
    if (!query) {
      throw new BadRequestException('query is required');
    }

    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;

    return this.users.searchUsers({
      userId: user.sub,
      query,
      limit: parsedLimit,
    });
  }

  @UseGuards(RateLimitGuard)
  @Get('username-available')
  async usernameAvailable(@Query('username') username?: string) {
    if (!username) {
      throw new BadRequestException('username is required');
    }

    const available = await this.users.isUsernameAvailable(username);
    return { available };
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/follow')
  toggleFollow(
    @CurrentUser() user: JwtPayload,
    @Param('id') targetUserId: string,
  ) {
    return this.users.toggleFollow({
      followerId: user.sub,
      followingId: targetUserId,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id/follow')
  setFollow(
    @CurrentUser() user: JwtPayload,
    @Param('id') targetUserId: string,
    @Body() dto: FollowStateDto,
  ) {
    return this.users.setFollow({
      followerId: user.sub,
      followingId: targetUserId,
      follow: dto.follow,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/follower')
  removeFollower(
    @CurrentUser() user: JwtPayload,
    @Param('id') targetUserId: string,
  ) {
    return this.users.removeFollower({
      userId: user.sub,
      followerId: targetUserId,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/connection')
  removeConnection(
    @CurrentUser() user: JwtPayload,
    @Param('id') targetUserId: string,
  ) {
    return this.users.removeConnection({
      userId: user.sub,
      targetUserId,
    });
  }
}
