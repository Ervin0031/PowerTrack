import { Plus } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useExercise } from './exercises-provider'

export function ExercisePrimaryButtons() {
  const { setOpen } = useExercise()
  return (
    <div className='flex gap-2'>
      <Button className='space-x-1' onClick={() => setOpen('add')}>
        <span>添加动作</span> <Plus size={18} />
      </Button>
    </div>
  )
}
