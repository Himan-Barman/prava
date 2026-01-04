import { Injectable, UnauthorizedException } from '@nestjs/common';
import jwt from 'jsonwebtoken';

import { config } from '@/app.config';
import { JwtPayload } from '@/common/types/jwt-payload';

@Injectable()
export class JwtService {
  verify(token: string): JwtPayload {
    try {
      return jwt.verify(
        token,
        config.JWT_PUBLIC_KEY,
        {
          algorithms: ['RS256'],
        }
      ) as JwtPayload;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }
}
