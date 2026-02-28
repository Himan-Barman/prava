export interface AuthUserContext {
  userId: string;
  email?: string;
  username?: string;
}

declare module "fastify" {
  interface FastifyRequest {
    user?: AuthUserContext;
  }
}

export {};
