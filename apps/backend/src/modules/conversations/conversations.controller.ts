import {
  BadRequestException,
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
import { ConversationsService } from './conversations.service';
import { CreateDmDto } from './dto/create-dm.dto';
import { CreateGroupDto } from './dto/create-group.dto';
import { AddMembersDto } from './dto/add-members.dto';

@UseGuards(JwtAuthGuard)
@Controller('conversations')
export class ConversationsController {
  constructor(private readonly conversations: ConversationsService) {}

  @Get()
  list(@CurrentUser() user: JwtPayload) {
    return this.conversations.listForUser(user.sub);
  }

  @Post('dm')
  async createDm(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateDmDto,
  ) {
    try {
      return await this.conversations.createDm({
        userId: user.sub,
        otherUserId: dto.otherUserId,
      });
    } catch (err) {
      throw new BadRequestException('Failed to create DM');
    }
  }

  @Post('group')
  async createGroup(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateGroupDto,
  ) {
    try {
      return await this.conversations.createGroup({
        userId: user.sub,
        title: dto.title,
        memberIds: dto.memberIds,
      });
    } catch (err) {
      throw new BadRequestException('Failed to create group');
    }
  }

  @Get(':id/members')
  async listMembers(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
  ) {
    const member = await this.conversations.getMembership({
      conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new BadRequestException('Not a member of conversation');
    }

    return this.conversations.listMembers(conversationId);
  }

  @Post(':id/members')
  async addMembers(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
    @Body() dto: AddMembersDto,
  ) {
    try {
      return await this.conversations.addMembers({
        conversationId,
        requesterId: user.sub,
        memberIds: dto.memberIds,
      });
    } catch (err) {
      throw new BadRequestException('Failed to add members');
    }
  }

  @Post(':id/leave')
  async leave(
    @CurrentUser() user: JwtPayload,
    @Param('id') conversationId: string,
  ) {
    await this.conversations.leaveConversation({
      conversationId,
      userId: user.sub,
    });
    return { success: true };
  }
}
