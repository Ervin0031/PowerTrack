import { MuscleGroupActionDialog } from './muscle-group-action-dialog'
import { MuscleGroupDeleteDialog } from './muscle-group-delete-dialog'
import { useMuscleGroup } from './muscle-group-provider'

export function MuscleGroupDialogs({ onSuccess }: { onSuccess: () => void }) {
  const { open, setOpen, currentRow, setCurrentRow } = useMuscleGroup()
  return (
    <>
      <MuscleGroupActionDialog
        key='muscle-group-add'
        open={open === 'add'}
        onOpenChange={() => setOpen('add')}
        onSuccess={onSuccess}
      />
      {currentRow && (
        <>
          <MuscleGroupActionDialog
            key={`muscle-group-edit-${currentRow.id}`}
            open={open === 'edit'}
            onOpenChange={() => {
              setOpen('edit')
              setTimeout(() => setCurrentRow(null), 500)
            }}
            currentRow={currentRow}
            onSuccess={onSuccess}
          />
          <MuscleGroupDeleteDialog
            key={`muscle-group-delete-${currentRow.id}`}
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
