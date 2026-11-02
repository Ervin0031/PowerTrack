import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? '',
  headers: { 'Content-Type': 'application/json' },
})

// Inject token on every request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// ponytail: single refresh in-flight to avoid thundering herd on 401
let isRefreshing = false
let refreshQueue: Array<(token: string) => void> = []

function resolveQueue(token: string) {
  refreshQueue.forEach((cb) => cb(token))
  refreshQueue = []
}

function rejectQueue(error: unknown) {
  refreshQueue.forEach(() => {
    // queue items will reject via the original request
  })
  refreshQueue = []
}

api.interceptors.response.use(
  (res) => res,
  async (error) => {
    if (!axios.isAxiosError(error) || error.response?.status !== 401) {
      return Promise.reject(error)
    }

    const originalRequest = error.config
    // Don't retry refresh itself or auth endpoints
    if (
      !originalRequest ||
      originalRequest.url?.includes('/auth/refresh') ||
      originalRequest.url?.includes('/auth/login') ||
      originalRequest.url?.includes('/auth/register')
    ) {
      clearAuthAndRedirect()
      return Promise.reject(error)
    }

    // Already retried once — give up
    if ((originalRequest as { _retry?: boolean })._retry) {
      clearAuthAndRedirect()
      return Promise.reject(error)
    }

    const refreshToken = localStorage.getItem('refresh_token')
    if (!refreshToken) {
      clearAuthAndRedirect()
      return Promise.reject(error)
    }

    if (!isRefreshing) {
      isRefreshing = true
      try {
        const res = await axios.post(
          `${api.defaults.baseURL}/api/v1/auth/refresh`,
          { refresh_token: refreshToken },
          { headers: { 'Content-Type': 'application/json' } },
        )
        const newToken = res.data.access_token
        localStorage.setItem('access_token', newToken)
        resolveQueue(newToken)
        isRefreshing = false
        originalRequest.headers.Authorization = `Bearer ${newToken}`
        ;(originalRequest as { _retry?: boolean })._retry = true
        return api(originalRequest)
      } catch {
        rejectQueue(null)
        isRefreshing = false
        clearAuthAndRedirect()
        return Promise.reject(error)
      }
    }

    // Another request is already refreshing — queue this one
    return new Promise((resolve) => {
      refreshQueue.push((token: string) => {
        originalRequest.headers.Authorization = `Bearer ${token}`
        ;(originalRequest as { _retry?: boolean })._retry = true
        resolve(api(originalRequest))
      })
    })
  },
)

function clearAuthAndRedirect() {
  localStorage.removeItem('access_token')
  localStorage.removeItem('refresh_token')
  if (
    typeof window !== 'undefined' &&
    !window.location.pathname.startsWith('/sign-in')
  ) {
    window.location.href = `/sign-in?redirect=${encodeURIComponent(window.location.pathname)}`
  }
}

export { api }
