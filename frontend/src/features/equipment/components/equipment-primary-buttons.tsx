import { Plus } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useEquipment } from './equipment-provider'

export function EquipmentPrimaryButtons() {
  const { setOpen } = useEquipment()
  return (
    <div className='flex gap-2'>
      <Button className='space-x-1' onClick={() => setOpen('add')}>
        <span>添加器械</span> <Plus size={18} />
      </Button>
    </div>
  )
}
