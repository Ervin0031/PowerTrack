import { api } from '@/lib/api'
import type { Equipment } from './schema'

interface ListResponse {
  items: Equipment[]
  total: number
}

export async function fetchEquipment(params?: { skip?: number; limit?: number }): Promise<ListResponse> {
  const res = await api.get<ListResponse>('/api/v1/exercises/equipment', { params })
  return res.data
}

export async function createEquipment(data: { name: string; name_en: string }) {
  const res = await api.post<Equipment>('/api/v1/exercises/equipment', data)
  return res.data
}

export async function updateEquipment(id: number, data: { name?: string; name_en?: string }) {
  const res = await api.put<Equipment>(`/api/v1/exercises/equipment/${id}`, data)
  return res.data
}

export async function deleteEquipment(id: number) {
  await api.delete(`/api/v1/exercises/equipment/${id}`)
}
