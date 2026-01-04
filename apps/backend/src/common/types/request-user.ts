import { JwtPayload } from '@/common/types/jwt-payload';

export interface AuthenticatedRequest {
  user: JwtPayload;
}
