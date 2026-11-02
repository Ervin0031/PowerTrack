import { z } from 'zod'

export const muscleGroupRefSchema = z.object({
  id: z.number(),
  name: z.string(),
  name_en: z.string(),
  category: z.string(),
})

export const exerciseSchema = z.object({
  id: z.number(),
  name: z.string(),
  name_en: z.string().nullable(),
  exercise_type: z.string(),
  primary_muscle_group_id: z.number(),
  equipment_id: z.number().nullable(),
  instructions: z.string().nullable(),
  is_custom: z.boolean().optional(),
  created_at: z.string(),
  primary_muscle_name: z.string().nullable(),
  primary_muscle_name_en: z.string().nullable(),
  equipment_name: z.string().nullable(),
  equipment_name_en: z.string().nullable(),
  secondary_muscles: z.array(muscleGroupRefSchema).optional(),
  image_url: z.string().nullable(),
})
export type Exercise = z.infer<typeof exerciseSchema>

export const exerciseTypeLabels: Record<string, string> = {
  compound: '复合动作',
  isolation: '孤立动作',
}
