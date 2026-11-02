import { useState } from 'react'
import { type Table } from '@tanstack/react-table'
import { Trash2, UserX, UserCheck } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@/components/ui/tooltip'
import { DataTableBulkActions as BulkActionsToolbar } from '@/components/data-table'
import { type User } from '../data/schema'
import { updateUser } from '../data/api'
import { UsersMultiDeleteDialog } from './users-multi-delete-dialog'

type DataTableBulkActionsProps<TData> = {
  table: Table<TData>
  onSuccess?: () => void
}

export function DataTableBulkActions<TData>({
  table,
  onSuccess,
}: DataTableBulkActionsProps<TData>) {
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const selectedRows = table.getFilteredSelectedRowModel().rows

  const handleBulkStatusChange = async (is_active: boolean) => {
    const selectedUsers = selectedRows.map((row) => row.original as User)
    const label = is_active ? '激活' : '停用'
    try {
      // ponytail: sequential updates, add batch endpoint if throughput matters
      await Promise.all(selectedUsers.map((u) => updateUser(u.id, { is_active })))
      toast.success(`已${label} ${selectedUsers.length} 位用户`)
      table.resetRowSelection()
      onSuccess?.()
    } catch {
      toast.error(`${label}用户失败`)
    }
  }

  return (
    <>
      <BulkActionsToolbar table={table} entityName='用户'>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              variant='outline'
              size='icon'
              onClick={() => handleBulkStatusChange(true)}
              className='size-8'
              aria-label='激活选中的用户'
              title='激活选中的用户'
            >
              <UserCheck />
              <span className='sr-only'>激活选中的用户</span>
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>激活选中的用户</p>
          </TooltipContent>
        </Tooltip>

        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              variant='outline'
              size='icon'
              onClick={() => handleBulkStatusChange(false)}
              className='size-8'
              aria-label='停用选中的用户'
              title='停用选中的用户'
            >
              <UserX />
              <span className='sr-only'>停用选中的用户</span>
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>停用选中的用户</p>
          </TooltipContent>
        </Tooltip>

        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              variant='destructive'
              size='icon'
              onClick={() => setShowDeleteConfirm(true)}
              className='size-8'
              aria-label='删除选中的用户'
              title='删除选中的用户'
            >
              <Trash2 />
              <span className='sr-only'>删除选中的用户</span>
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>删除选中的用户</p>
          </TooltipContent>
        </Tooltip>
      </BulkActionsToolbar>

      <UsersMultiDeleteDialog
        table={table}
        open={showDeleteConfirm}
        onOpenChange={setShowDeleteConfirm}
        onSuccess={onSuccess}
      />
    </>
  )
}
