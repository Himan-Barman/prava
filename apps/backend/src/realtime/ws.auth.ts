import jwt from 'jsonwebtoken';
import { config } from '@/app.config';
import { JwtPayload } from '@/common/types/jwt-payload';

export function verifyWsToken(token?: string): JwtPayload {
  if (!token) {
    throw new Error('Missing token');
  }

  const payload = jwt.verify(
    token,
    config.JWT_PUBLIC_KEY,
    { algorithms: ['RS256'] }
  ) as JwtPayload;

  return payload;
}
