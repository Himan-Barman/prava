import { Body, Controller, Post, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '@/common/guards/jwt.guard';
import { CurrentUser } from '@/common/decorators/user.decorator';
import { JwtPayload } from '@/common/types/jwt-payload';
import { SupportService } from './support.service';
import { SupportTicketDto } from './dto/support-ticket.dto';

@Controller('support')
export class SupportController {
  constructor(private readonly support: SupportService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  createTicket(
    @CurrentUser() user: JwtPayload,
    @Body() dto: SupportTicketDto,
  ) {
    return this.support.createTicket({
      userId: user.sub,
      type: dto.type,
      category: dto.category,
      message: dto.message,
      includeLogs: dto.includeLogs,
      allowContact: dto.allowContact,
      score: dto.score,
    });
  }
}
