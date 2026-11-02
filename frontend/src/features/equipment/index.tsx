import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { type PaginationState } from '@tanstack/react-table'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { Search } from '@/components/search'
import { ThemeSwitch } from '@/components/theme-switch'
import { EquipmentDialogs } from './components/equipment-dialogs'
import { EquipmentPrimaryButtons } from './components/equipment-primary-buttons'
import { EquipmentProvider } from './components/equipment-provider'
import { EquipmentTable } from './components/equipment-table'
import { fetchEquipment } from './data/api'

export function Equipment() {
  const queryClient = useQueryClient()
  const [pagination, setPagination] = useState<PaginationState>({ pageIndex: 0, pageSize: 10 })

  const { data, isLoading, isError } = useQuery({
    queryKey: ['equipment', pagination],
    queryFn: () =>
      fetchEquipment({
        skip: pagination.pageIndex * pagination.pageSize,
        limit: pagination.pageSize,
      }),
  })

  return (
    <EquipmentProvider>
      <Header fixed>
        <Search className='me-auto' />
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>

      <Main className='flex flex-1 flex-col gap-4 sm:gap-6'>
        <div className='flex flex-wrap items-end justify-between gap-2'>
          <div>
            <h2 className='text-2xl font-bold tracking-tight'>器械管理</h2>
            <p className='text-muted-foreground'>管理训练器械，提供中英文名称。</p>
          </div>
          <EquipmentPrimaryButtons />
        </div>

        {isLoading ? (
          <div className='flex flex-1 items-center justify-center text-muted-foreground'>加载中...</div>
        ) : isError ? (
          <div className='flex flex-1 items-center justify-center text-destructive'>器械数据加载失败。</div>
        ) : (
          <EquipmentTable
            data={data?.items ?? []}
            totalCount={data?.total ?? 0}
            pagination={pagination}
            onPaginationChange={setPagination}
          />
        )}
      </Main>

      <EquipmentDialogs onSuccess={() => queryClient.invalidateQueries({ queryKey: ['equipment'] })} />
    </EquipmentProvider>
  )
}
