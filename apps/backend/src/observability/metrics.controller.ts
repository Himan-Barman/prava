import { Controller, Get, Res } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { metricsContentType, metricsSnapshot } from './metrics';

@Controller('metrics')
export class MetricsController {
  @Get()
  async getMetrics(@Res() reply: FastifyReply) {
    const body = await metricsSnapshot();
    reply.header('Content-Type', metricsContentType());
    reply.send(body);
  }
}
