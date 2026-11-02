import { createFileRoute } from '@tanstack/react-router'
import { MuscleGroups } from '@/features/muscle-groups'

export const Route = createFileRoute('/_authenticated/exercises/muscle-groups')({
  component: MuscleGroups,
})
