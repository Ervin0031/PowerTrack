import React, { useState } from 'react'
import useDialogState from '@/hooks/use-dialog-state'
import { type MuscleGroup } from '../data/schema'

type MuscleGroupDialogType = 'add' | 'edit' | 'delete'

type MuscleGroupContextType = {
  open: MuscleGroupDialogType | null
  setOpen: (str: MuscleGroupDialogType | null) => void
  currentRow: MuscleGroup | null
  setCurrentRow: React.Dispatch<React.SetStateAction<MuscleGroup | null>>
}

const MuscleGroupContext = React.createContext<MuscleGroupContextType | null>(null)

export function MuscleGroupProvider({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useDialogState<MuscleGroupDialogType>(null)
  const [currentRow, setCurrentRow] = useState<MuscleGroup | null>(null)

  return (
    <MuscleGroupContext value={{ open, setOpen, currentRow, setCurrentRow }}>
      {children}
    </MuscleGroupContext>
  )
}

// eslint-disable-next-line react-refresh/only-export-components
export const useMuscleGroup = () => {
  const context = React.useContext(MuscleGroupContext)
  if (!context) throw new Error('useMuscleGroup must be used within <MuscleGroupContext>')
  return context
}
