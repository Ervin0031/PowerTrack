import { type ColumnDef } from '@tanstack/react-table'
import { cn } from '@/lib/utils'
import { Checkbox } from '@/components/ui/checkbox'
import { DataTableColumnHeader } from '@/components/data-table'
import { type Equipment } from '../data/schema'
import { DataTableRowActions } from './data-table-row-actions'

export const equipmentColumns: ColumnDef<Equipment>[] = [
  {
    id: 'select',
    header: ({ table }) => (
      <Checkbox
        checked={
          table.getIsAllPageRowsSelected() ||
          (table.getIsSomePageRowsSelected() && 'indeterminate')
        }
        onCheckedChange={(value) => table.toggleAllPageRowsSelected(!!value)}
        aria-label='全选'
        className='translate-y-0.5'
      />
    ),
    meta: {
      className: cn('inset-s-0 z-10 rounded-tl-[inherit] max-md:sticky'),
    },
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
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='ID' />
    ),
    cell: ({ row }) => (
      <span className='ps-3 text-sm'>{row.getValue('id')}</span>
    ),
    meta: {
      className: cn('inset-s-6 w-16 ps-0.5 max-md:sticky'),
    },
    enableHiding: false,
  },
  {
    accessorKey: 'name',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='中文名称' />
    ),
    cell: ({ row }) => (
      <div className='ps-3 font-medium'>{row.getValue('name')}</div>
    ),
  },
  {
    accessorKey: 'name_en',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='英文名称' />
    ),
    cell: ({ row }) => <div className='ps-3'>{row.getValue('name_en')}</div>,
  },
  {
    id: 'actions',
    cell: DataTableRowActions,
  },
]
