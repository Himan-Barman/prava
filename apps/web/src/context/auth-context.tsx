import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { authService, AuthSession } from '../services/auth-service';

interface User {
  id: string;
  email: string;
  isVerified: boolean;
}

interface AuthContextValue {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<AuthSession>;
  register: (email: string, password: string, username?: string) => Promise<AuthSession>;
  logout: () => Promise<void>;
  setUser: (user: User | null) => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check if user is already logged in
    const checkAuth = async () => {
      try {
        if (authService.isLoggedIn()) {
          const userId = authService.getUserId();
          if (userId) {
            // In a real app, you'd fetch user data here
            setUser({ id: userId, email: '', isVerified: true });
          }
        }
      } catch (error) {
        console.error('Auth check failed:', error);
      } finally {
        setIsLoading(false);
      }
    };

    checkAuth();
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const session = await authService.login(email, password);
    setUser({
      id: session.userId,
      email: session.email,
      isVerified: session.isVerified,
    });
    return session;
  }, []);

  const register = useCallback(async (email: string, password: string, username?: string) => {
    const session = await authService.register(email, password, username);
    setUser({
      id: session.userId,
      email: session.email,
      isVerified: session.isVerified,
    });
    return session;
  }, []);

  const logout = useCallback(async () => {
    await authService.logout();
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        isLoading,
        login,
        register,
        logout,
        setUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
