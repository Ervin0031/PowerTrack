import { create } from 'zustand'
import type { UserResponse } from '@/features/auth/data/schema'

interface AuthUser {
  id: number
  username: string
  email: string
  is_active: boolean
  is_verified: boolean
  is_superuser: boolean
}

interface AuthState {
  auth: {
    user: AuthUser | null
    setUser: (user: AuthUser | null) => void
    accessToken: string
    refreshTokenValue: string
    setTokens: (accessToken: string, refreshToken: string | null) => void
    reset: () => void
  }
}

function loadToken(key: string): string {
  if (typeof window === 'undefined') return ''
  return localStorage.getItem(key) ?? ''
}

export const useAuthStore = create<AuthState>()((set) => ({
  auth: {
    user: null,
    setUser: (user) =>
      set((state) => ({ ...state, auth: { ...state.auth, user } })),

    accessToken: loadToken('access_token'),
    refreshTokenValue: loadToken('refresh_token'),

    setTokens: (accessToken, refreshToken) =>
      set((state) => {
        localStorage.setItem('access_token', accessToken)
        if (refreshToken) {
          localStorage.setItem('refresh_token', refreshToken)
        } else {
          localStorage.removeItem('refresh_token')
        }
        return {
          ...state,
          auth: {
            ...state.auth,
            accessToken,
            refreshTokenValue: refreshToken ?? '',
          },
        }
      }),

    reset: () =>
      set((state) => {
        localStorage.removeItem('access_token')
        localStorage.removeItem('refresh_token')
        return {
          ...state,
          auth: { ...state.auth, user: null, accessToken: '', refreshTokenValue: '' },
        }
      }),
  },
}))

// ponytail: helper to map backend UserResponse -> store AuthUser
export function toAuthUser(u: UserResponse): AuthUser {
  return {
    id: u.id,
    username: u.username,
    email: u.email,
    is_active: u.is_active,
    is_verified: u.is_verified,
    is_superuser: u.is_superuser,
  }
}
