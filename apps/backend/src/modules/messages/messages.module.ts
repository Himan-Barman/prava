import { Module } from '@nestjs/common';
import { ConversationsModule } from '@/modules/conversations/conversations.module';
import { MediaModule } from '@/modules/media/media.module';
import { MessagesController } from './messages.controller';
import { MessagesService } from './messages.service';

@Module({
  imports: [ConversationsModule, MediaModule],
  controllers: [MessagesController],
  providers: [MessagesService],
  exports: [MessagesService],
})
export class MessagesModule {}
