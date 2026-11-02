import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { type PaginationState } from '@tanstack/react-table'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { Search } from '@/components/search'
import { ThemeSwitch } from '@/components/theme-switch'
import { fetchEquipment } from '@/features/equipment/data/api'
import { fetchMuscleGroups } from '@/features/muscle-groups/data/api'
import { ExerciseDialogs } from './components/exercises-dialogs'
import { ExercisePrimaryButtons } from './components/exercises-primary-buttons'
import { ExerciseProvider } from './components/exercises-provider'
import { ExercisesTable } from './components/exercises-table'
import { fetchExercises } from './data/api'

export function Exercises() {
  const queryClient = useQueryClient()
  const [pagination, setPagination] = useState<PaginationState>({ pageIndex: 0, pageSize: 10 })

  const { data, isLoading, isError } = useQuery({
    queryKey: ['exercises', pagination],
    queryFn: () =>
      fetchExercises({
        skip: pagination.pageIndex * pagination.pageSize,
        limit: pagination.pageSize,
      }),
  })

  // Equipment and muscle groups are small — fetch full lists for filter dropdowns
  const { data: muscleGroupsData } = useQuery({
    queryKey: ['muscle-groups'],
    queryFn: () => fetchMuscleGroups({ limit: 100 }),
    staleTime: 5 * 60 * 1000,
  })

  const { data: equipmentData } = useQuery({
    queryKey: ['equipment'],
    queryFn: () => fetchEquipment({ limit: 100 }),
    staleTime: 5 * 60 * 1000,
  })

  const muscleGroups = muscleGroupsData?.items ?? []
  const equipment = equipmentData?.items ?? []

  return (
    <ExerciseProvider>
      <Header fixed>
        <Search className='me-auto' />
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>

      <Main className='flex flex-1 flex-col gap-4 sm:gap-6'>
        <div className='flex flex-wrap items-end justify-between gap-2'>
          <div>
            <h2 className='text-2xl font-bold tracking-tight'>动作库</h2>
            <p className='text-muted-foreground'>管理训练动作库，支持搜索、筛选与示范图片上传。</p>
          </div>
          <ExercisePrimaryButtons />
        </div>

        {isLoading ? (
          <div className='flex flex-1 items-center justify-center text-muted-foreground'>加载中...</div>
        ) : isError ? (
          <div className='flex flex-1 items-center justify-center text-destructive'>动作数据加载失败。</div>
        ) : (
          <ExercisesTable
            data={data?.items ?? []}
            totalCount={data?.total ?? 0}
            pagination={pagination}
            onPaginationChange={setPagination}
            muscleGroups={muscleGroups}
            equipment={equipment}
          />
        )}
      </Main>

      <ExerciseDialogs onSuccess={() => queryClient.invalidateQueries({ queryKey: ['exercises'] })} />
    </ExerciseProvider>
  )
}
