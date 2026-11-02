import React, { useState } from 'react'
import useDialogState from '@/hooks/use-dialog-state'
import { type Equipment } from '../data/schema'

type EquipmentDialogType = 'add' | 'edit' | 'delete'

type EquipmentContextType = {
  open: EquipmentDialogType | null
  setOpen: (str: EquipmentDialogType | null) => void
  currentRow: Equipment | null
  setCurrentRow: React.Dispatch<React.SetStateAction<Equipment | null>>
}

const EquipmentContext = React.createContext<EquipmentContextType | null>(null)

export function EquipmentProvider({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useDialogState<EquipmentDialogType>(null)
  const [currentRow, setCurrentRow] = useState<Equipment | null>(null)

  return (
    <EquipmentContext value={{ open, setOpen, currentRow, setCurrentRow }}>
      {children}
    </EquipmentContext>
  )
}

// eslint-disable-next-line react-refresh/only-export-components
export const useEquipment = () => {
  const context = React.useContext(EquipmentContext)
  if (!context) throw new Error('useEquipment must be used within <EquipmentContext>')
  return context
}
