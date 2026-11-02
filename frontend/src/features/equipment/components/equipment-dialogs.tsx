import { EquipmentActionDialog } from './equipment-action-dialog'
import { EquipmentDeleteDialog } from './equipment-delete-dialog'
import { useEquipment } from './equipment-provider'

export function EquipmentDialogs({ onSuccess }: { onSuccess: () => void }) {
  const { open, setOpen, currentRow, setCurrentRow } = useEquipment()
  return (
    <>
      <EquipmentActionDialog
        key='equipment-add'
        open={open === 'add'}
        onOpenChange={() => setOpen('add')}
        onSuccess={onSuccess}
      />
      {currentRow && (
        <>
          <EquipmentActionDialog
            key={`equipment-edit-${currentRow.id}`}
            open={open === 'edit'}
            onOpenChange={() => {
              setOpen('edit')
              setTimeout(() => setCurrentRow(null), 500)
            }}
            currentRow={currentRow}
            onSuccess={onSuccess}
          />
          <EquipmentDeleteDialog
            key={`equipment-delete-${currentRow.id}`}
            open={open === 'delete'}
            onOpenChange={() => {
              setOpen('delete')
              setTimeout(() => setCurrentRow(null), 500)
            }}
            currentRow={currentRow}
            onSuccess={onSuccess}
          />
        </>
      )}
    </>
  )
}
