import { z } from 'zod'

// --- Backend response types ---

export const userResponseSchema = z.object({
  id: z.number(),
  username: z.string(),
  email: z.string().email(),
  is_active: z.boolean(),
  is_verified: z.boolean(),
  is_superuser: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  last_login_at: z.string().nullable(),
})
export type UserResponse = z.infer<typeof userResponseSchema>

export const tokenSchema = z.object({
  access_token: z.string(),
  refresh_token: z.string().nullable(),
  token_type: z.string(),
})
export type Token = z.infer<typeof tokenSchema>

export const refreshTokenResponseSchema = z.object({
  id: z.number(),
  user_id: z.number(),
  device_name: z.string().nullable(),
  device_type: z.string().nullable(),
  expires_at: z.string(),
  is_revoked: z.boolean(),
  created_at: z.string(),
  last_used_at: z.string().nullable(),
  ip_address: z.string().nullable(),
})
export type RefreshTokenResponse = z.infer<typeof refreshTokenResponseSchema>

// --- Request types ---

export interface LoginRequest {
  email?: string | null
  username?: string | null
  password: string
}

export interface RegisterRequest {
  username: string
  email: string
  password: string
}

export interface RefreshTokenRequest {
  refresh_token: string
}

export interface EmailVerificationRequest {
  email: string
  code: string
}

export interface ResendVerificationRequest {
  email: string
}

export interface PasswordResetRequest {
  email: string
}

export interface PasswordResetConfirm {
  email: string
  code: string
  new_password: string
}

export interface PasswordChange {
  old_password: string
  new_password: string
}
