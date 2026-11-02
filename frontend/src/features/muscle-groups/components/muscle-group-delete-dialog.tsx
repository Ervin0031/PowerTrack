import { useState } from 'react'
import { toast } from 'sonner'
import { AlertTriangle } from 'lucide-react'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ConfirmDialog } from '@/components/confirm-dialog'
import { deleteMuscleGroup } from '../data/api'
import { type MuscleGroup } from '../data/schema'

type MuscleGroupDeleteDialogProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  currentRow: MuscleGroup
  onSuccess: () => void
}

export function MuscleGroupDeleteDialog({ open, onOpenChange, currentRow, onSuccess }: MuscleGroupDeleteDialogProps) {
  const [value, setValue] = useState('')

  const handleDelete = async () => {
    if (value.trim() !== currentRow.name) return
    try {
      await deleteMuscleGroup(currentRow.id)
      toast.success('肌群已删除')
      onOpenChange(false)
      onSuccess()
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? '删除失败'
      toast.error(msg)
    }
  }

  return (
    <ConfirmDialog
      open={open}
      onOpenChange={onOpenChange}
      form='muscle-group-delete-form'
      disabled={value.trim() !== currentRow.name}
      title={
        <span className='text-destructive'>
          <AlertTriangle className='me-1 inline-block stroke-destructive' size={18} /> 删除肌群
        </span>
      }
      desc={
        <form
          id='muscle-group-delete-form'
          onSubmit={(e) => {
            e.preventDefault()
            handleDelete()
          }}
          className='space-y-4'
        >
          <p className='mb-2'>
            确定要删除肌群 <span className='font-bold'>{currentRow.name}</span>？
            <br />
            若该肌群已被动作引用，则无法删除。
          </p>
          <Label className='my-2'>
            肌群名称：
            <Input
              value={value}
              onChange={(e) => setValue(e.target.value)}
              placeholder='输入肌群名称以确认删除。'
              autoFocus
            />
          </Label>
          <Alert variant='destructive'>
            <AlertTitle>警告！</AlertTitle>
            <AlertDescription>请谨慎操作，此操作无法撤销。</AlertDescription>
          </Alert>
        </form>
      }
      confirmText='删除'
      destructive
    />
  )
}
