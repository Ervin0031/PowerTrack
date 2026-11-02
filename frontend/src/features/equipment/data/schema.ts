import { z } from 'zod'

export const equipmentSchema = z.object({
  id: z.number(),
  name: z.string(),
  name_en: z.string(),
})
export type Equipment = z.infer<typeof equipmentSchema>
