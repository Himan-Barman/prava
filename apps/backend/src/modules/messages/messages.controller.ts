import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '@/common/guards/jwt.guard';
import { CurrentUser } from '@/common/decorators/user.decorator';
import { JwtPayload } from '@/common/types/jwt-payload';
import { ConversationsService } from '@/modules/conversations/conversations.service';
import { MessagesService } from './messages.service';
import { SendMessageDto } from './dto/send-message.dto';
import { ReadReceiptDto } from './dto/read-receipt.dto';
import { DeliveryReceiptDto } from './dto/delivery-receipt.dto';
import { EditMessageDto } from './dto/edit-message.dto';
import { MessageReactionDto } from './dto/message-reaction.dto';

@UseGuards(JwtAuthGuard)
@Controller('conversations')
export class MessagesController {
  constructor(
    private readonly messages: MessagesService,
    private readonly conversations: ConversationsService,
  ) {}

  @Get(':id/messages')
  async listMessages(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Query('beforeSeq') beforeSeq?: string,
    @Query('limit') limit?: string,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    const parsedBefore =
      beforeSeq && Number.isFinite(Number(beforeSeq))
        ? Number(beforeSeq)
        : undefined;
    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;

    return this.messages.listMessages({
      conversationId,
      beforeSeq: parsedBefore,
      limit: parsedLimit,
    });
  }

  @Post(':id/messages')
  async sendMessage(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Body() dto: SendMessageDto,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    const parsedDate = dto.clientTimestamp
      ? new Date(dto.clientTimestamp)
      : null;
    const clientTimestamp =
      parsedDate && !Number.isNaN(parsedDate.getTime())
        ? parsedDate
        : null;

    const result = await this.messages.sendMessage({
      conversationId,
      senderUserId: user.sub,
      senderDeviceId: dto.deviceId,
      body: dto.body ?? '',
      contentType: dto.contentType,
      clientTimestamp,
      clientTempId: dto.tempId ?? null,
      mediaAssetId: dto.mediaAssetId ?? null,
    });

    return result;
  }

  @Post(':id/read')
  async markRead(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Body() dto: ReadReceiptDto,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    await this.messages.markRead({
      conversationId,
      userId: user.sub,
      deviceId: dto.deviceId,
      lastReadSeq: dto.lastReadSeq,
    });

    return { success: true };
  }

  @Get(':id/messages/:messageId/receipts')
  async listReceipts(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Param('messageId') messageId: string,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    const message = await this.messages.getMessage({
      conversationId,
      messageId,
    });
    if (!message) {
      throw new NotFoundException('Message not found');
    }

    if (message.senderUserId !== user.sub) {
      throw new ForbiddenException('Receipts restricted to sender');
    }

    return this.messages.listMessageReceipts({
      conversationId,
      messageId,
    });
  }

  @Post(':id/delivered')
  async markDelivered(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Body() dto: DeliveryReceiptDto,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    await this.messages.markDelivered({
      conversationId,
      userId: user.sub,
      deviceId: dto.deviceId,
      lastDeliveredSeq: dto.lastDeliveredSeq,
    });

    return { success: true };
  }

  @Patch(':id/messages/:messageId')
  async editMessage(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Param('messageId') messageId: string,
    @Body() dto: EditMessageDto,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    const updated = await this.messages.editMessage({
      conversationId,
      messageId,
      userId: user.sub,
      body: dto.body,
    });

    if (!updated) {
      throw new ForbiddenException('Cannot edit message');
    }

    return updated;
  }

  @Delete(':id/messages/:messageId')
  async deleteMessage(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Param('messageId') messageId: string,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    const updated = await this.messages.deleteMessageForAll({
      conversationId,
      messageId,
      userId: user.sub,
    });

    if (!updated) {
      throw new ForbiddenException('Cannot delete message');
    }

    return updated;
  }

  @Post(':id/messages/:messageId/reactions')
  async setReaction(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Param('messageId') messageId: string,
    @Body() dto: MessageReactionDto,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    const reaction = await this.messages.setReaction({
      conversationId,
      messageId,
      userId: user.sub,
      emoji: dto.emoji,
    });

    if (!reaction) {
      throw new ForbiddenException('Cannot react to message');
    }

    return reaction;
  }

  @Delete(':id/messages/:messageId/reactions')
  async removeReaction(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Param('messageId') messageId: string,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    const removed = await this.messages.removeReaction({
      conversationId,
      messageId,
      userId: user.sub,
    });

    return { removed };
  }
}
