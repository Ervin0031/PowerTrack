import { ExerciseActionDialog } from './exercises-action-dialog'
import { ExerciseDeleteDialog } from './exercises-delete-dialog'
import { useExercise } from './exercises-provider'

export function ExerciseDialogs({ onSuccess }: { onSuccess: () => void }) {
  const { open, setOpen, currentRow, setCurrentRow } = useExercise()
  return (
    <>
      <ExerciseActionDialog
        key='exercise-add'
        open={open === 'add'}
        onOpenChange={() => setOpen('add')}
        onSuccess={onSuccess}
      />
      {currentRow && (
        <>
          <ExerciseActionDialog
            key={`exercise-edit-${currentRow.id}`}
            open={open === 'edit'}
            onOpenChange={() => {
              setOpen('edit')
              setTimeout(() => setCurrentRow(null), 500)
            }}
            currentRow={currentRow}
            onSuccess={onSuccess}
          />
          <ExerciseDeleteDialog
            key={`exercise-delete-${currentRow.id}`}
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
