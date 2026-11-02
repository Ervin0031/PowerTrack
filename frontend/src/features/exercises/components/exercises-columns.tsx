import { type ColumnDef } from '@tanstack/react-table'
import { cn } from '@/lib/utils'
import { Badge } from '@/components/ui/badge'
import { Checkbox } from '@/components/ui/checkbox'
import { DataTableColumnHeader } from '@/components/data-table'
import { type Exercise, exerciseTypeLabels } from '../data/schema'
import { DataTableRowActions } from './data-table-row-actions'

export function getExerciseColumns(
  muscleGroupMap: Record<number, string>,
  equipmentMap: Record<number, string>,
): ColumnDef<Exercise>[] {
  return [
    {
      id: 'select',
      header: ({ table }) => (
        <Checkbox
          checked={table.getIsAllPageRowsSelected() || (table.getIsSomePageRowsSelected() && 'indeterminate')}
          onCheckedChange={(value) => table.toggleAllPageRowsSelected(!!value)}
          aria-label='全选'
          className='translate-y-0.5'
        />
      ),
      meta: { className: cn('inset-s-0 z-10 rounded-tl-[inherit] max-md:sticky') },
      cell: ({ row }) => (
        <Checkbox
          checked={row.getIsSelected()}
          onCheckedChange={(value) => row.toggleSelected(!!value)}
          aria-label='选择行'
          className='translate-y-0.5'
        />
      ),
      enableSorting: false,
      enableHiding: false,
    },
    {
      accessorKey: 'id',
      header: ({ column }) => <DataTableColumnHeader column={column} title='ID' />,
      cell: ({ row }) => <span className='ps-3 text-sm'>{row.getValue('id')}</span>,
      meta: { className: cn('inset-s-6 ps-0.5 max-md:sticky w-16') },
      enableHiding: false,
    },
    {
      accessorKey: 'name',
      header: ({ column }) => <DataTableColumnHeader column={column} title='中文名称' />,
      cell: ({ row }) => {
        const imageUrl = row.original.image_url
        return (
          <div className='flex items-center gap-2 ps-3'>
            {imageUrl ? (
              <img src={imageUrl} alt='' className='h-8 w-8 rounded object-cover' />
            ) : (
              <div className='h-8 w-8 rounded bg-muted' />
            )}
            <span className='font-medium'>{row.getValue('name')}</span>
          </div>
        )
      },
    },
    {
      accessorKey: 'exercise_type',
      header: ({ column }) => <DataTableColumnHeader column={column} title='类型' />,
      cell: ({ row }) => {
        const t = row.getValue<string>('exercise_type')
        return <Badge variant='outline'>{exerciseTypeLabels[t] ?? t}</Badge>
      },
      enableSorting: false,
    },
    {
      accessorKey: 'primary_muscle_group_id',
      header: ({ column }) => <DataTableColumnHeader column={column} title='主肌群' />,
      cell: ({ row }) => {
        const id = row.getValue<number>('primary_muscle_group_id')
        return <div className='ps-3'>{muscleGroupMap[id] ?? id ?? '-'}</div>
      },
      filterFn: (row, columnId, filterValue: string[]) =>
        filterValue.length === 0 || filterValue.includes(String(row.getValue(columnId))),
    },
    {
      accessorKey: 'equipment_id',
      header: ({ column }) => <DataTableColumnHeader column={column} title='器械' />,
      cell: ({ row }) => {
        const id = row.getValue<number | null>('equipment_id')
        return <div className='ps-3'>{id != null ? (equipmentMap[id] ?? id) : '-'}</div>
      },
      filterFn: (row, columnId, filterValue: string[]) =>
        filterValue.length === 0 || filterValue.includes(String(row.getValue(columnId))),
    },
    {
      id: 'actions',
      cell: DataTableRowActions,
    },
  ]
}
