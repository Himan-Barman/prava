import { Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '@/common/guards/jwt.guard';
import { CurrentUser } from '@/common/decorators/user.decorator';
import { JwtPayload } from '@/common/types/jwt-payload';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @UseGuards(JwtAuthGuard)
  @Get()
  list(
    @CurrentUser() user: JwtPayload,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;

    return this.notifications.listForUser({
      userId: user.sub,
      limit: parsedLimit,
      cursor,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Get('unread-count')
  unreadCount(@CurrentUser() user: JwtPayload) {
    return this.notifications.countUnread(user.sub).then((count) => ({
      count,
    }));
  }

  @UseGuards(JwtAuthGuard)
  @Post('read-all')
  markAllRead(@CurrentUser() user: JwtPayload) {
    return this.notifications.markAllRead(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/read')
  markRead(
    @CurrentUser() user: JwtPayload,
    @Param('id') notificationId: string,
  ) {
    return this.notifications.markRead({
      userId: user.sub,
      notificationId,
    });
  }
}
