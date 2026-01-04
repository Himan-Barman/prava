import { Module } from '@nestjs/common';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { HealthModule } from './health/health.module';
import { ConversationsModule } from './modules/conversations/conversations.module';
import { MessagesModule } from './modules/messages/messages.module';
import { DevicesModule } from './modules/devices/devices.module';
import { MediaModule } from './modules/media/media.module';
import { E2eModule } from './modules/e2e/e2e.module';
import { MetricsModule } from './observability/metrics.module';
import { FeedModule } from './modules/feed/feed.module';
import { NotificationsModule } from './modules/notifications/notifications.module';

@Module({
  imports: [
    AuthModule,
    UsersModule,
    HealthModule,
    ConversationsModule,
    MessagesModule,
    DevicesModule,
    MediaModule,
    E2eModule,
    MetricsModule,
    FeedModule,
    NotificationsModule,
  ],
})
export class AppModule {}
