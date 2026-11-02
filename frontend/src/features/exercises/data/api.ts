import { api } from '@/lib/api'
import type { Exercise } from './schema'

interface ListParams {
  skip?: number
  limit?: number
  search?: string
  muscle_group_id?: number
  equipment_id?: number
  exercise_type?: string
}

interface ListResponse {
  items: Exercise[]
  total: number
}

export async function fetchExercises(params: ListParams = {}): Promise<ListResponse> {
  const res = await api.get<ListResponse>('/api/v1/exercises', { params })
  return res.data
}

export async function fetchExercise(id: number): Promise<Exercise> {
  const res = await api.get<Exercise>(`/api/v1/exercises/${id}`)
  return res.data
}

export async function createExercise(data: Record<string, unknown>, image?: File) {
  const formData = new FormData()
  formData.append('data', JSON.stringify(data))
  if (image) formData.append('image', image)
  const res = await api.post<Exercise>('/api/v1/exercises', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return res.data
}

export async function updateExercise(id: number, data: Record<string, unknown>, image?: File) {
  const formData = new FormData()
  formData.append('data', JSON.stringify(data))
  if (image) formData.append('image', image)
  const res = await api.put<Exercise>(`/api/v1/exercises/${id}`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return res.data
}

export async function deleteExercise(id: number) {
  await api.delete(`/api/v1/exercises/${id}`)
}
