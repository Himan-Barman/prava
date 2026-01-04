import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { finalize } from 'rxjs/operators';
import { recordHttpRequest } from './metrics';

@Injectable()
export class MetricsInterceptor implements NestInterceptor {
  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    if (context.getType() !== 'http') {
      return next.handle();
    }

    const http = context.switchToHttp();
    const req = http.getRequest<{ method?: string }>();
    const res = http.getResponse<{ statusCode?: number }>();
    const start = process.hrtime.bigint();

    return next.handle().pipe(
      finalize(() => {
        const end = process.hrtime.bigint();
        const durationSeconds =
          Number(end - start) / 1_000_000_000;
        const method = req?.method ?? 'UNKNOWN';
        const status = String(res?.statusCode ?? 0);
        recordHttpRequest(method, status, durationSeconds);
      }),
    );
  }
}
