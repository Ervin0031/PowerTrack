import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { type PaginationState } from '@tanstack/react-table'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { Search } from '@/components/search'
import { ThemeSwitch } from '@/components/theme-switch'
import { MuscleGroupDialogs } from './components/muscle-group-dialogs'
import { MuscleGroupPrimaryButtons } from './components/muscle-group-primary-buttons'
import { MuscleGroupProvider } from './components/muscle-group-provider'
import { MuscleGroupTable } from './components/muscle-group-table'
import { fetchMuscleGroups } from './data/api'

export function MuscleGroups() {
  const queryClient = useQueryClient()
  const [pagination, setPagination] = useState<PaginationState>({ pageIndex: 0, pageSize: 10 })

  const { data, isLoading, isError } = useQuery({
    queryKey: ['muscle-groups', pagination],
    queryFn: () =>
      fetchMuscleGroups({
        skip: pagination.pageIndex * pagination.pageSize,
        limit: pagination.pageSize,
      }),
  })

  return (
    <MuscleGroupProvider>
      <Header fixed>
        <Search className='me-auto' />
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>

      <Main className='flex flex-1 flex-col gap-4 sm:gap-6'>
        <div className='flex flex-wrap items-end justify-between gap-2'>
          <div>
            <h2 className='text-2xl font-bold tracking-tight'>肌群管理</h2>
            <p className='text-muted-foreground'>管理训练肌群，按上肢/下肢/核心分类。</p>
          </div>
          <MuscleGroupPrimaryButtons />
        </div>

        {isLoading ? (
          <div className='flex flex-1 items-center justify-center text-muted-foreground'>加载中...</div>
        ) : isError ? (
          <div className='flex flex-1 items-center justify-center text-destructive'>肌群数据加载失败。</div>
        ) : (
          <MuscleGroupTable
            data={data?.items ?? []}
            totalCount={data?.total ?? 0}
            pagination={pagination}
            onPaginationChange={setPagination}
          />
        )}
      </Main>

      <MuscleGroupDialogs onSuccess={() => queryClient.invalidateQueries({ queryKey: ['muscle-groups'] })} />
    </MuscleGroupProvider>
  )
}
