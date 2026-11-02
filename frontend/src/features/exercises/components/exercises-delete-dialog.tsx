import { useState } from 'react'
import { toast } from 'sonner'
import { AlertTriangle } from 'lucide-react'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ConfirmDialog } from '@/components/confirm-dialog'
import { deleteExercise } from '../data/api'
import { type Exercise } from '../data/schema'

type ExerciseDeleteDialogProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  currentRow: Exercise
  onSuccess: () => void
}

export function ExerciseDeleteDialog({ open, onOpenChange, currentRow, onSuccess }: ExerciseDeleteDialogProps) {
  const [value, setValue] = useState('')

  const handleDelete = async () => {
    if (value.trim() !== currentRow.name) return
    try {
      await deleteExercise(currentRow.id)
      toast.success('动作已删除')
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
      form='exercise-delete-form'
      disabled={value.trim() !== currentRow.name}
      title={
        <span className='text-destructive'>
          <AlertTriangle className='me-1 inline-block stroke-destructive' size={18} /> 删除动作
        </span>
      }
      desc={
        <form
          id='exercise-delete-form'
          onSubmit={(e) => {
            e.preventDefault()
            handleDelete()
          }}
          className='space-y-4'
        >
          <p className='mb-2'>
            确定要删除动作 <span className='font-bold'>{currentRow.name}</span>？
            <br />
            此操作将永久删除该动作及其关联的示范图片。
          </p>
          <Label className='my-2'>
            动作名称：
            <Input
              value={value}
              onChange={(e) => setValue(e.target.value)}
              placeholder='输入动作名称以确认删除。'
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
