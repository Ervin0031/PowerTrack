import React, { useState } from 'react'
import useDialogState from '@/hooks/use-dialog-state'
import { type Exercise } from '../data/schema'

type ExerciseDialogType = 'add' | 'edit' | 'delete'

type ExerciseContextType = {
  open: ExerciseDialogType | null
  setOpen: (str: ExerciseDialogType | null) => void
  currentRow: Exercise | null
  setCurrentRow: React.Dispatch<React.SetStateAction<Exercise | null>>
}

const ExerciseContext = React.createContext<ExerciseContextType | null>(null)

export function ExerciseProvider({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useDialogState<ExerciseDialogType>(null)
  const [currentRow, setCurrentRow] = useState<Exercise | null>(null)

  return (
    <ExerciseContext value={{ open, setOpen, currentRow, setCurrentRow }}>
      {children}
    </ExerciseContext>
  )
}

// eslint-disable-next-line react-refresh/only-export-components
export const useExercise = () => {
  const context = React.useContext(ExerciseContext)
  if (!context) throw new Error('useExercise must be used within <ExerciseContext>')
  return context
}
