import { api } from '@/lib/api'
import type { MuscleGroup } from './schema'

interface ListResponse {
  items: MuscleGroup[]
  total: number
}

export async function fetchMuscleGroups(params?: { skip?: number; limit?: number; category?: string }): Promise<ListResponse> {
  const res = await api.get<ListResponse>('/api/v1/exercises/muscle-groups', { params })
  return res.data
}

export async function createMuscleGroup(data: { name: string; name_en: string; category: string }) {
  const res = await api.post<MuscleGroup>('/api/v1/exercises/muscle-groups', data)
  return res.data
}

export async function updateMuscleGroup(id: number, data: { name?: string; name_en?: string; category?: string }) {
  const res = await api.put<MuscleGroup>(`/api/v1/exercises/muscle-groups/${id}`, data)
  return res.data
}

export async function deleteMuscleGroup(id: number) {
  await api.delete(`/api/v1/exercises/muscle-groups/${id}`)
}
