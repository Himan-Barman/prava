import { Injectable } from '@nestjs/common';
import * as crypto from 'crypto';
import jwt from 'jsonwebtoken';

import { config } from '@/app.config';

@Injectable()
export class TokenService {
  private readonly accessTTL = '15m';
  private readonly refreshTTL_DAYS = 30;

  signAccessToken(payload: { sub: string }) {
    return jwt.sign(payload, config.JWT_PRIVATE_KEY, {
      algorithm: 'RS256',
      expiresIn: this.accessTTL,
    });
  }

  generateRefreshToken() {
    const raw = crypto.randomBytes(64).toString('hex');
    const hash = crypto
      .createHash('sha256')
      .update(raw)
      .digest('hex');

    return { raw, hash };
  }

  refreshExpiryDate() {
    return new Date(
      Date.now() + this.refreshTTL_DAYS * 24 * 60 * 60 * 1000
    );
  }
}
