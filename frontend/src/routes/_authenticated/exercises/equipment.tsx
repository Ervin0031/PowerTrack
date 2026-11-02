import { createFileRoute } from '@tanstack/react-router'
import { Equipment } from '@/features/equipment'

export const Route = createFileRoute('/_authenticated/exercises/equipment')({
  component: Equipment,
})
