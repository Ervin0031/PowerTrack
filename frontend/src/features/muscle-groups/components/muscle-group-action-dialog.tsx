import { useState } from 'react'
import { z } from 'zod'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { createMuscleGroup, updateMuscleGroup } from '../data/api'
import { type MuscleGroup } from '../data/schema'

const formSchema = z.object({
  name: z.string().min(1, '请输入中文名称。'),
  name_en: z.string().min(1, '请输入英文名称。'),
  category: z.enum(['upper', 'lower', 'core']),
})

type MuscleGroupForm = z.infer<typeof formSchema>

type MuscleGroupActionDialogProps = {
  currentRow?: MuscleGroup
  open: boolean
  onOpenChange: (open: boolean) => void
  onSuccess: () => void
}

export function MuscleGroupActionDialog({ currentRow, open, onOpenChange, onSuccess }: MuscleGroupActionDialogProps) {
  const isEdit = !!currentRow
  const [loading, setLoading] = useState(false)

  const form = useForm<MuscleGroupForm>({
    resolver: zodResolver(formSchema),
    defaultValues: isEdit
      ? { name: currentRow.name, name_en: currentRow.name_en, category: currentRow.category as 'upper' | 'lower' | 'core' }
      : { name: '', name_en: '', category: 'upper' },
  })

  async function onSubmit(values: MuscleGroupForm) {
    setLoading(true)
    try {
      if (isEdit) {
        await updateMuscleGroup(currentRow.id, values)
        toast.success('肌群更新成功')
      } else {
        await createMuscleGroup(values)
        toast.success('肌群创建成功')
      }
      form.reset()
      onOpenChange(false)
      onSuccess()
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? '操作失败'
      toast.error(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(state) => {
        form.reset()
        onOpenChange(state)
      }}
    >
      <DialogContent className='sm:max-w-lg'>
        <DialogHeader className='text-start'>
          <DialogTitle>{isEdit ? '编辑肌群' : '添加肌群'}</DialogTitle>
          <DialogDescription>{isEdit ? '修改肌群信息。' : '新增一个肌群。'}</DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form id='muscle-group-form' onSubmit={form.handleSubmit(onSubmit)} className='space-y-4'>
            <FormField
              control={form.control}
              name='name'
              render={({ field }) => (
                <FormItem>
                  <FormLabel>中文名称</FormLabel>
                  <FormControl><Input placeholder='例如：胸部' {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name='name_en'
              render={({ field }) => (
                <FormItem>
                  <FormLabel>英文名称</FormLabel>
                  <FormControl><Input placeholder='例如：Chest' {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name='category'
              render={({ field }) => (
                <FormItem>
                  <FormLabel>分类</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl>
                      <SelectTrigger><SelectValue placeholder='选择分类' /></SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value='upper'>上肢</SelectItem>
                      <SelectItem value='lower'>下肢</SelectItem>
                      <SelectItem value='core'>核心</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
          </form>
        </Form>
        <DialogFooter>
          <Button type='submit' form='muscle-group-form' disabled={loading}>
            {loading ? '保存中...' : '保存'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
