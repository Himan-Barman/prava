import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '@/common/guards/jwt.guard';
import { CurrentUser } from '@/common/decorators/user.decorator';
import { JwtPayload } from '@/common/types/jwt-payload';
import { FeedService } from './feed.service';
import { CreatePostDto } from './dto/create-post.dto';
import { CreateCommentDto } from './dto/create-comment.dto';

@UseGuards(JwtAuthGuard)
@Controller('feed')
export class FeedController {
  constructor(private readonly feed: FeedService) {}

  @Get()
  list(
    @CurrentUser() user: JwtPayload,
    @Query('limit') limit?: string,
    @Query('before') before?: string,
  ) {
    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;
    const parsedBefore = before ? new Date(before) : undefined;

    return this.feed.listFeed({
      userId: user.sub,
      limit: parsedLimit,
      before:
        parsedBefore && !Number.isNaN(parsedBefore.getTime())
          ? parsedBefore
          : undefined,
    });
  }

  @Post()
  create(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreatePostDto,
  ) {
    return this.feed.createPost({
      userId: user.sub,
      body: dto.body,
    });
  }

  @Post(':id/like')
  toggleLike(
    @CurrentUser() user: JwtPayload,
    @Param('id') postId: string,
  ) {
    return this.feed.toggleLike({
      userId: user.sub,
      postId,
    });
  }

  @Get(':id/comments')
  listComments(
    @CurrentUser() user: JwtPayload,
    @Param('id') postId: string,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit =
      limit && Number.isFinite(Number(limit))
        ? Number(limit)
        : undefined;

    return this.feed.listComments({
      postId,
      limit: parsedLimit,
    });
  }

  @Post(':id/comments')
  addComment(
    @CurrentUser() user: JwtPayload,
    @Param('id') postId: string,
    @Body() dto: CreateCommentDto,
  ) {
    return this.feed.addComment({
      userId: user.sub,
      postId,
      body: dto.body,
    });
  }

  @Post(':id/share')
  share(
    @CurrentUser() user: JwtPayload,
    @Param('id') postId: string,
  ) {
    return this.feed.sharePost({
      userId: user.sub,
      postId,
    });
  }
}
