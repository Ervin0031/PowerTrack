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
import { createEquipment, updateEquipment } from '../data/api'
import { type Equipment } from '../data/schema'

const formSchema = z.object({
  name: z.string().min(1, '请输入中文名称。'),
  name_en: z.string().min(1, '请输入英文名称。'),
})

type EquipmentForm = z.infer<typeof formSchema>

type EquipmentActionDialogProps = {
  currentRow?: Equipment
  open: boolean
  onOpenChange: (open: boolean) => void
  onSuccess: () => void
}

export function EquipmentActionDialog({ currentRow, open, onOpenChange, onSuccess }: EquipmentActionDialogProps) {
  const isEdit = !!currentRow
  const [loading, setLoading] = useState(false)

  const form = useForm<EquipmentForm>({
    resolver: zodResolver(formSchema),
    defaultValues: isEdit ? { name: currentRow.name, name_en: currentRow.name_en } : { name: '', name_en: '' },
  })

  async function onSubmit(values: EquipmentForm) {
    setLoading(true)
    try {
      if (isEdit) {
        await updateEquipment(currentRow.id, values)
        toast.success('器械更新成功')
      } else {
        await createEquipment(values)
        toast.success('器械创建成功')
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
          <DialogTitle>{isEdit ? '编辑器械' : '添加器械'}</DialogTitle>
          <DialogDescription>{isEdit ? '修改器械信息。' : '新增一个训练器械。'}</DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form id='equipment-form' onSubmit={form.handleSubmit(onSubmit)} className='space-y-4'>
            <FormField
              control={form.control}
              name='name'
              render={({ field }) => (
                <FormItem>
                  <FormLabel>中文名称</FormLabel>
                  <FormControl><Input placeholder='例如：杠铃' {...field} /></FormControl>
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
                  <FormControl><Input placeholder='例如：Barbell' {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </form>
        </Form>
        <DialogFooter>
          <Button type='submit' form='equipment-form' disabled={loading}>
            {loading ? '保存中...' : '保存'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
