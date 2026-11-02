import { createFileRoute } from '@tanstack/react-router'
import { Exercises } from '@/features/exercises'

export const Route = createFileRoute('/_authenticated/exercises/')({
  component: Exercises,
})
