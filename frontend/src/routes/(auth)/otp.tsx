import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod'
import { Otp } from '@/features/auth/otp'

const otpSearchSchema = z.object({
  email: z.string().email(),
  mode: z.enum(['verify-email', 'reset-password']),
})

export const Route = createFileRoute('/(auth)/otp')({
  component: Otp,
  validateSearch: otpSearchSchema,
})
