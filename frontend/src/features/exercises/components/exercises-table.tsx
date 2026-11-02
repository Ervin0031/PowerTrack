import { useState } from 'react'
import {
  type PaginationState,
  type SortingState,
  type ColumnFiltersState,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  useReactTable,
} from '@tanstack/react-table'
import { cn } from '@/lib/utils'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { DataTablePagination, DataTableToolbar } from '@/components/data-table'
import type { Equipment } from '@/features/equipment/data/schema'
import type { MuscleGroup } from '@/features/muscle-groups/data/schema'
import { type Exercise, exerciseTypeLabels } from '../data/schema'
import { getExerciseColumns } from './exercises-columns'

type DataTableProps = {
  data: Exercise[]
  totalCount: number
  pagination: PaginationState
  onPaginationChange: (p: PaginationState) => void
  muscleGroups: MuscleGroup[]
  equipment: Equipment[]
}

export function ExercisesTable({
  data,
  totalCount,
  pagination,
  onPaginationChange,
  muscleGroups,
  equipment,
}: DataTableProps) {
  const mgMap: Record<number, string> = Object.fromEntries(
    muscleGroups.map((mg) => [mg.id, mg.name]),
  )
  const eqMap: Record<number, string> = Object.fromEntries(
    equipment.map((eq) => [eq.id, eq.name]),
  )
  const columns = getExerciseColumns(mgMap, eqMap)
  const [rowSelection, setRowSelection] = useState({})
  const [sorting, setSorting] = useState<SortingState>([])
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([])

  const table = useReactTable({
    data,
    columns,
    state: { sorting, rowSelection, columnFilters, pagination },
    pageCount: Math.ceil(totalCount / pagination.pageSize),
    rowCount: totalCount,
    manualPagination: true,
    enableRowSelection: true,
    onRowSelectionChange: setRowSelection,
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    onPaginationChange: (updater) => {
      const next = typeof updater === 'function' ? updater(pagination) : updater
      onPaginationChange(next)
    },
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getSortedRowModel: getSortedRowModel(),
  })

  return (
    <div className={cn('flex flex-1 flex-col gap-4', 'max-sm:has-[div[role="toolbar"]]:mb-16')}>
      <DataTableToolbar
        table={table}
        searchKey='name'
        searchPlaceholder='搜索动作名称...'
        filters={[
          {
            columnId: 'exercise_type',
            title: '动作类型',
            options: Object.entries(exerciseTypeLabels).map(([value, label]) => ({ value, label })),
          },
          {
            columnId: 'primary_muscle_group_id',
            title: '主肌群',
            options: muscleGroups.map((mg) => ({ value: String(mg.id), label: mg.name })),
          },
          {
            columnId: 'equipment_id',
            title: '器械',
            options: equipment.map((eq) => ({ value: String(eq.id), label: eq.name })),
          },
        ]}
      />
      <div className='overflow-hidden rounded-md border'>
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id} className='group/row'>
                {headerGroup.headers.map((header) => (
                  <TableHead
                    key={header.id}
                    colSpan={header.colSpan}
                    className={cn(
                      'bg-background group-hover/row:bg-muted group-data-[state=selected]/row:bg-muted',
                      header.column.columnDef.meta?.className,
                      header.column.columnDef.meta?.thClassName,
                    )}
                  >
                    {header.isPlaceholder ? null : flexRender(header.column.columnDef.header, header.getContext())}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow key={row.id} data-state={row.getIsSelected() && 'selected'} className='group/row'>
                  {row.getVisibleCells().map((cell) => (
                    <TableCell
                      key={cell.id}
                      className={cn(
                        'bg-background group-hover/row:bg-muted group-data-[state=selected]/row:bg-muted',
                        cell.column.columnDef.meta?.className,
                        cell.column.columnDef.meta?.tdClassName,
                      )}
                    >
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={columns.length} className='h-24 text-center'>
                  暂无数据。
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
      <DataTablePagination table={table} className='mt-auto' />
    </div>
  )
}
