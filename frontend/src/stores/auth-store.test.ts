import { beforeEach, describe, expect, it, vi } from 'vitest'

async function importAuthStore() {
  const { useAuthStore } = await import('./auth-store')
  return useAuthStore
}

const sampleUser = {
  id: 1,
  username: 'testuser',
  email: 'user@example.com',
  is_active: true,
  is_verified: true,
  is_superuser: false,
}

describe('useAuthStore', () => {
  beforeEach(() => {
    localStorage.clear()
    vi.resetModules()
  })

  it('starts with empty tokens when nothing is persisted', async () => {
    const useAuthStore = await importAuthStore()

    expect(useAuthStore.getState().auth.accessToken).toBe('')
    expect(useAuthStore.getState().auth.refreshTokenValue).toBe('')
    expect(useAuthStore.getState().auth.user).toBeNull()
  })

  it('persists tokens so a new store instance reads them back', async () => {
    const useAuthStore = await importAuthStore()
    useAuthStore.getState().auth.setTokens('access-token', 'refresh-token')

    vi.resetModules()
    const useAuthStoreAfterReload = await importAuthStore()

    expect(useAuthStoreAfterReload.getState().auth.accessToken).toBe(
      'access-token',
    )
    expect(useAuthStoreAfterReload.getState().auth.refreshTokenValue).toBe(
      'refresh-token',
    )
  })

  it('updates the signed-in user via setUser', async () => {
    const useAuthStore = await importAuthStore()

    useAuthStore.getState().auth.setUser({ ...sampleUser })

    expect(useAuthStore.getState().auth.user).toEqual(sampleUser)
  })

  it('reset clears user and tokens and drops persistence', async () => {
    const useAuthStore = await importAuthStore()
    useAuthStore.getState().auth.setTokens('t1', 't2')
    useAuthStore.getState().auth.setUser({ ...sampleUser })

    useAuthStore.getState().auth.reset()

    expect(useAuthStore.getState().auth.user).toBeNull()
    expect(useAuthStore.getState().auth.accessToken).toBe('')
    expect(useAuthStore.getState().auth.refreshTokenValue).toBe('')

    vi.resetModules()
    const useAuthStoreAfterReload = await importAuthStore()

    expect(useAuthStoreAfterReload.getState().auth.user).toBeNull()
    expect(useAuthStoreAfterReload.getState().auth.accessToken).toBe('')
    expect(useAuthStoreAfterReload.getState().auth.refreshTokenValue).toBe('')
  })
})
