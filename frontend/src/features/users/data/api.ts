import { api } from '@/lib/api'
import type { UserResponse } from '@/features/auth/data/schema'

export async function fetchCurrentUser(): Promise<UserResponse> {
  const res = await api.get<UserResponse>('/api/v1/users/me')
  return res.data
}

export async function updateCurrentUser(
  data: Partial<{
    username: string
    email: string
    password: string
    is_active: boolean
  }>,
): Promise<UserResponse> {
  const res = await api.put<UserResponse>('/api/v1/users/me', data)
  return res.data
}

export async function deleteCurrentUser(): Promise<void> {
  await api.delete('/api/v1/users/me')
}

// Admin endpoints
export async function fetchUsers(params?: {
  skip?: number
  limit?: number
}): Promise<UserResponse[]> {
  const res = await api.get<UserResponse[]>('/api/v1/users/', { params })
  return res.data
}

export async function fetchUser(userId: number): Promise<UserResponse> {
  const res = await api.get<UserResponse>(`/api/v1/users/${userId}`)
  return res.data
}

export async function updateUser(
  userId: number,
  data: Partial<{
    username: string
    email: string
    password: string
    is_active: boolean
  }>,
): Promise<UserResponse> {
  const res = await api.put<UserResponse>(`/api/v1/users/${userId}`, data)
  return res.data
}

export async function deleteUser(userId: number): Promise<void> {
  await api.delete(`/api/v1/users/${userId}`)
}
