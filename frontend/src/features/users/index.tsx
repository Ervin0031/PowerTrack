import { useQuery, useQueryClient } from '@tanstack/react-query'
import { getRouteApi } from '@tanstack/react-router'
import { ConfigDrawer } from '@/components/config-drawer'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { Search } from '@/components/search'
import { ThemeSwitch } from '@/components/theme-switch'
import { UsersDialogs } from './components/users-dialogs'
import { UsersPrimaryButtons } from './components/users-primary-buttons'
import { UsersProvider } from './components/users-provider'
import { UsersTable } from './components/users-table'
import { fetchUsers } from './data/api'

const route = getRouteApi('/_authenticated/users/')

export function Users() {
  const search = route.useSearch()
  const navigate = route.useNavigate()
  const queryClient = useQueryClient()

  const { data: users = [], isLoading, isError } = useQuery({
    queryKey: ['users'],
    queryFn: () => fetchUsers({ limit: 500 }),
  })

  const onSuccess = () => queryClient.invalidateQueries({ queryKey: ['users'] })

  return (
    <UsersProvider>
      <Header fixed>
        <Search className='me-auto' />
        <ThemeSwitch />
        <ConfigDrawer />
        <ProfileDropdown />
      </Header>

      <Main className='flex flex-1 flex-col gap-4 sm:gap-6'>
        <div className='flex flex-wrap items-end justify-between gap-2'>
          <div>
            <h2 className='text-2xl font-bold tracking-tight'>用户管理</h2>
            <p className='text-muted-foreground'>
              管理用户及其权限。
            </p>
          </div>
          <UsersPrimaryButtons />
        </div>

        {isLoading ? (
          <div className='flex flex-1 items-center justify-center text-muted-foreground'>加载中...</div>
        ) : isError ? (
          <div className='flex flex-1 items-center justify-center text-destructive'>用户数据加载失败。</div>
        ) : (
          <UsersTable data={users} search={search} navigate={navigate} onSuccess={onSuccess} />
        )}
      </Main>

      <UsersDialogs onSuccess={() => queryClient.invalidateQueries({ queryKey: ['users'] })} />
    </UsersProvider>
  )
}
