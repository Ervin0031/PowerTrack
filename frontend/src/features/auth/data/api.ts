import { api } from '@/lib/api'
import type {
  Token,
  UserResponse,
  RefreshTokenResponse,
  LoginRequest,
  RegisterRequest,
  RefreshTokenRequest,
  EmailVerificationRequest,
  ResendVerificationRequest,
  PasswordResetRequest,
  PasswordResetConfirm,
  PasswordChange,
} from './schema'

// ponytail: plain axios functions, match existing equipment pattern

export async function login(data: LoginRequest): Promise<Token> {
  const res = await api.post<Token>('/api/v1/auth/login', data)
  return res.data
}

export async function register(data: RegisterRequest): Promise<UserResponse> {
  const res = await api.post<UserResponse>('/api/v1/auth/register', data)
  return res.data
}

export async function logout(data: RefreshTokenRequest): Promise<void> {
  await api.post('/api/v1/auth/logout', data)
}

export async function logoutAll(): Promise<void> {
  await api.post('/api/v1/auth/logout-all')
}

export async function refreshToken(
  data: RefreshTokenRequest,
): Promise<{ access_token: string; token_type: string }> {
  const res = await api.post<{ access_token: string; token_type: string }>(
    '/api/v1/auth/refresh',
    data,
  )
  return res.data
}

export async function verifyEmail(data: EmailVerificationRequest): Promise<void> {
  await api.post('/api/v1/auth/verify-email', data)
}

export async function resendVerification(
  data: ResendVerificationRequest,
): Promise<void> {
  await api.post('/api/v1/auth/resend-verification', data)
}

export async function forgotPassword(data: PasswordResetRequest): Promise<void> {
  await api.post('/api/v1/auth/forgot-password', data)
}

export async function resetPassword(data: PasswordResetConfirm): Promise<void> {
  await api.post('/api/v1/auth/reset-password', data)
}

export async function changePassword(data: PasswordChange): Promise<void> {
  await api.post('/api/v1/auth/change-password', data)
}

export async function listDevices(): Promise<RefreshTokenResponse[]> {
  const res = await api.get<RefreshTokenResponse[]>('/api/v1/auth/devices')
  return res.data
}
