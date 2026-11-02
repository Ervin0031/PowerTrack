import { useState } from 'react'
import { AlertTriangle } from 'lucide-react'
import { toast } from 'sonner'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ConfirmDialog } from '@/components/confirm-dialog'
import { type User } from '../data/schema'
import { deleteUser } from '../data/api'

type UserDeleteDialogProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  currentRow: User
  onSuccess?: () => void
}

export function UsersDeleteDialog({
  open,
  onOpenChange,
  currentRow,
  onSuccess,
}: UserDeleteDialogProps) {
  const [value, setValue] = useState('')

  const handleDelete = async () => {
    if (value.trim() !== currentRow.username) return

    try {
      await deleteUser(currentRow.id)
      toast.success(`用户 ${currentRow.username} 已删除`)
      onSuccess?.()
      onOpenChange(false)
    } catch {
      toast.error('删除用户失败')
    }
  }

  return (
    <ConfirmDialog
      open={open}
      onOpenChange={onOpenChange}
      form='users-delete-form'
      disabled={value.trim() !== currentRow.username}
      title={
        <span className='text-destructive'>
          <AlertTriangle
            className='me-1 inline-block stroke-destructive'
            size={18}
          />{' '}
          删除用户
        </span>
      }
      desc={
        <form
          id='users-delete-form'
          onSubmit={(e) => {
            e.preventDefault()
            handleDelete()
          }}
          className='space-y-4'
        >
          <p className='mb-2'>
            确定要删除用户{' '}
            <span className='font-bold'>{currentRow.username}</span>？
            <br />
            此操作将永久从系统中删除该用户，不可撤销。
          </p>

          <Label className='my-2'>
            用户名：
            <Input
              value={value}
              onChange={(e) => setValue(e.target.value)}
              placeholder='请输入用户名以确认删除'
              autoFocus
            />
          </Label>

          <Alert variant='destructive'>
            <AlertTitle>警告！</AlertTitle>
            <AlertDescription>
              请谨慎操作，此操作不可回滚。
            </AlertDescription>
          </Alert>
        </form>
      }
      confirmText='删除'
      destructive
    />
  )
}
