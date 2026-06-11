export interface AuthUserContext {
  userId: string;
  email?: string;
  username?: string;
  sessionId?: string;
  role?: string;
}

declare module "fastify" {
  interface FastifyRequest {
    user?: AuthUserContext;
  }
}

export {};
