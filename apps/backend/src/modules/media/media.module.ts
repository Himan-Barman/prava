import { Module } from '@nestjs/common';
import { ConversationsModule } from '@/modules/conversations/conversations.module';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';

@Module({
  imports: [ConversationsModule],
  controllers: [MediaController],
  providers: [MediaService],
  exports: [MediaService],
})
export class MediaModule {}
