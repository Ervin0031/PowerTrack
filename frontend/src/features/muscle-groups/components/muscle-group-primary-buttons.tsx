import { Plus } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useMuscleGroup } from './muscle-group-provider'

export function MuscleGroupPrimaryButtons() {
  const { setOpen } = useMuscleGroup()
  return (
    <div className='flex gap-2'>
      <Button className='space-x-1' onClick={() => setOpen('add')}>
        <span>添加肌群</span> <Plus size={18} />
      </Button>
    </div>
  )
}
