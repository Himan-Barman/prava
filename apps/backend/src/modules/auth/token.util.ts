import crypto from 'crypto';

export function generateToken(): {
  raw: string;
  hash: string;
} {
  const raw = crypto.randomBytes(32).toString('hex');
  const hash = crypto.createHash('sha256').update(raw).digest('hex');
  return { raw, hash };
}
