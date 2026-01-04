import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  NotFoundException,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '@/common/guards/jwt.guard';
import { CurrentUser } from '@/common/decorators/user.decorator';
import { JwtPayload } from '@/common/types/jwt-payload';
import { ConversationsService } from '@/modules/conversations/conversations.service';
import { InitMediaDto } from './dto/init-media.dto';
import { CompleteMediaDto } from './dto/complete-media.dto';
import { MediaService } from './media.service';

@UseGuards(JwtAuthGuard)
@Controller('media')
export class MediaController {
  constructor(
    private readonly media: MediaService,
    private readonly conversations: ConversationsService,
  ) {}

  @Post('init')
  async initUpload(
    @CurrentUser() user: JwtPayload,
    @Body() dto: InitMediaDto,
  ) {
    const member = await this.conversations.getMembership({
      conversationId: dto.conversationId,
      userId: user.sub,
    });
    if (!member) {
      throw new ForbiddenException('Not a member of conversation');
    }

    return this.media.initUpload({
      userId: user.sub,
      conversationId: dto.conversationId,
      contentType: dto.contentType,
      fileName: dto.fileName,
      sizeBytes: dto.sizeBytes,
      sha256: dto.sha256,
      retentionPolicy: dto.retentionPolicy,
      encryptionAlgorithm: dto.encryptionAlgorithm,
      encryptionKeyId: dto.encryptionKeyId,
      encryptionIv: dto.encryptionIv,
      encryptionKeyHash: dto.encryptionKeyHash,
      metadata: dto.metadata,
    });
  }

  @Post(':id/complete')
  async completeUpload(
    @CurrentUser() user: JwtPayload,
    @Param('id') assetId: string,
    @Body() dto: CompleteMediaDto,
  ) {
    return this.media.completeUpload({
      assetId,
      userId: user.sub,
      sizeBytes: dto.sizeBytes,
      sha256: dto.sha256,
      metadata: dto.metadata,
      fileName: dto.fileName,
    });
  }

  @Get(':id')
  async getMedia(
    @CurrentUser() user: JwtPayload,
    @Param('id') assetId: string,
  ) {
    const result = await this.media.getAssetForUser({
      assetId,
      userId: user.sub,
    });

    if (!result) {
      throw new NotFoundException('Media not found');
    }

    return result;
  }
}
