import { api } from '@/lib/api'

export async function healthCheck(): Promise<unknown> {
  const res = await api.get('/health')
  return res.data
}
