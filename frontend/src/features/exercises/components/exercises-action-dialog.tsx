import { useState, useRef } from 'react'
import { z } from 'zod'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery } from '@tanstack/react-query'
import { toast } from 'sonner'
import { Upload } from 'lucide-react'
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
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { fetchEquipment } from '@/features/equipment/data/api'
import { fetchMuscleGroups } from '@/features/muscle-groups/data/api'
import { createExercise, updateExercise } from '../data/api'
import { type Exercise } from '../data/schema'

const formSchema = z.object({
  name: z.string().min(1, '请输入中文名称。'),
  name_en: z.string().optional(),
  exercise_type: z.enum(['compound', 'isolation']),
  primary_muscle_group_id: z.string().min(1, '请选择主肌群。'),
  equipment_id: z.string().optional(),
  instructions: z.string().optional(),
})

type ExerciseForm = z.infer<typeof formSchema>

type ExerciseActionDialogProps = {
  currentRow?: Exercise
  open: boolean
  onOpenChange: (open: boolean) => void
  onSuccess: () => void
}

export function ExerciseActionDialog({ currentRow, open, onOpenChange, onSuccess }: ExerciseActionDialogProps) {
  const isEdit = !!currentRow
  const [loading, setLoading] = useState(false)
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(currentRow?.image_url ?? null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const { data: equipment = [] } = useQuery({
    queryKey: ['equipment'],
    queryFn: fetchEquipment,
    select: (data) => data.items,
  })

  const { data: muscleGroups = [] } = useQuery({
    queryKey: ['muscle-groups'],
    queryFn: fetchMuscleGroups,
    select: (data) => data.items,
  })

  const form = useForm<ExerciseForm>({
    resolver: zodResolver(formSchema),
    defaultValues: isEdit
      ? {
          name: currentRow.name,
          name_en: currentRow.name_en ?? '',
          exercise_type: currentRow.exercise_type as 'compound' | 'isolation',
          primary_muscle_group_id: String(currentRow.primary_muscle_group_id),
          equipment_id: currentRow.equipment_id ? String(currentRow.equipment_id) : '',
          instructions: currentRow.instructions ?? '',
        }
      : { name: '', name_en: '', exercise_type: 'compound', primary_muscle_group_id: '', equipment_id: '', instructions: '' },
  })

  const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      setImageFile(file)
      setImagePreview(URL.createObjectURL(file))
    }
  }

  async function onSubmit(values: ExerciseForm) {
    setLoading(true)
    try {
      const payload: Record<string, unknown> = {
        name: values.name,
        name_en: values.name_en || null,
        exercise_type: values.exercise_type,
        primary_muscle_group_id: Number(values.primary_muscle_group_id),
        equipment_id: values.equipment_id ? Number(values.equipment_id) : null,
        instructions: values.instructions || null,
      }
      if (isEdit) {
        await updateExercise(currentRow.id, payload, imageFile ?? undefined)
        toast.success('动作更新成功')
      } else {
        await createExercise(payload, imageFile ?? undefined)
        toast.success('动作创建成功')
      }
      form.reset()
      setImageFile(null)
      setImagePreview(null)
      onOpenChange(false)
      onSuccess()
    } catch (err: unknown) {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      const msg = typeof detail === 'string' ? detail : '操作失败'
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
        setImageFile(null)
        setImagePreview(null)
        onOpenChange(state)
      }}
    >
      <DialogContent className='sm:max-w-xl'>
        <DialogHeader className='text-start'>
          <DialogTitle>{isEdit ? '编辑动作' : '添加动作'}</DialogTitle>
          <DialogDescription>{isEdit ? '修改动作信息。' : '新增一个训练动作。'}</DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form id='exercise-form' onSubmit={form.handleSubmit(onSubmit)} className='space-y-4'>
            <div className='grid grid-cols-2 gap-4'>
              <FormField
                control={form.control}
                name='name'
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>中文名称</FormLabel>
                    <FormControl><Input placeholder='例如：卧推' {...field} /></FormControl>
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
                    <FormControl><Input placeholder='例如：Bench Press' {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
            <div className='grid grid-cols-2 gap-4'>
              <FormField
                control={form.control}
                name='exercise_type'
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>动作类型</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl><SelectTrigger><SelectValue placeholder='选择类型' /></SelectTrigger></FormControl>
                      <SelectContent>
                        <SelectItem value='compound'>复合动作</SelectItem>
                        <SelectItem value='isolation'>孤立动作</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name='primary_muscle_group_id'
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>主肌群</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl><SelectTrigger><SelectValue placeholder='选择肌群' /></SelectTrigger></FormControl>
                      <SelectContent>
                        {muscleGroups.map((mg) => (
                          <SelectItem key={mg.id} value={String(mg.id)}>{mg.name} ({mg.name_en})</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
            <FormField
              control={form.control}
              name='equipment_id'
              render={({ field }) => (
                <FormItem>
                  <FormLabel>器械（可选）</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl><SelectTrigger><SelectValue placeholder='选择器械' /></SelectTrigger></FormControl>
                    <SelectContent>
                      {equipment.map((eq) => (
                        <SelectItem key={eq.id} value={String(eq.id)}>{eq.name} ({eq.name_en})</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name='instructions'
              render={({ field }) => (
                <FormItem>
                  <FormLabel>动作说明</FormLabel>
                  <FormControl><Textarea placeholder='输入动作要点...' rows={3} {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <div>
              <FormLabel className='mb-2 block'>示范图片（可选）</FormLabel>
              <div className='flex items-center gap-4'>
                <Button type='button' variant='outline' size='sm' onClick={() => fileInputRef.current?.click()}>
                  <Upload size={16} className='me-1' /> 上传图片
                </Button>
                <input ref={fileInputRef} type='file' accept='image/*' className='hidden' onChange={handleImageChange} />
                {imagePreview && (
                  <img src={imagePreview} alt='预览' className='h-16 w-16 rounded border object-cover' />
                )}
              </div>
            </div>
          </form>
        </Form>
        <DialogFooter>
          <Button type='submit' form='exercise-form' disabled={loading}>
            {loading ? '保存中...' : '保存'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
