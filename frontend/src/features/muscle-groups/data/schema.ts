import { z } from 'zod'

export const muscleGroupSchema = z.object({
  id: z.number(),
  name: z.string(),
  name_en: z.string(),
  category: z.string(),
})
export type MuscleGroup = z.infer<typeof muscleGroupSchema>
