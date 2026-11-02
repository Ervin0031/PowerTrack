import { useState } from 'react'
import { z } from 'zod'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useNavigate } from '@tanstack/react-router'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'
import { verifyEmail, resetPassword } from '@/features/auth/data/api'
import { Button } from '@/components/ui/button'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot,
  InputOTPSeparator,
} from '@/components/ui/input-otp'
import { PasswordInput } from '@/components/password-input'

function formSchema(mode: 'verify-email' | 'reset-password') {
  const base = z.object({
    otp: z
      .string()
      .min(6, '请输入6位验证码。')
      .max(6, '请输入6位验证码。'),
  })
  if (mode === 'reset-password') {
    return base.extend({
      newPassword: z
        .string()
        .min(1, '请输入新密码。')
        .min(7, '密码长度至少为7位。'),
    })
  }
  return base
}

interface OtpFormProps extends React.HTMLAttributes<HTMLFormElement> {
  email: string
  mode: 'verify-email' | 'reset-password'
}

export function OtpForm({
  className,
  email,
  mode,
  ...props
}: OtpFormProps) {
  const navigate = useNavigate()
  const [isLoading, setIsLoading] = useState(false)

  const schema = formSchema(mode)
  type FormValues = z.infer<typeof schema>

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues:
      mode === 'reset-password'
        ? { otp: '', newPassword: '' }
        : { otp: '' },
  })

  // eslint-disable-next-line react-hooks/incompatible-library
  const otp = form.watch('otp')

  async function onSubmit(data: FormValues) {
    setIsLoading(true)

    try {
      if (mode === 'verify-email') {
        await verifyEmail({ email, code: data.otp })
        toast.success('邮箱验证成功！现在可以登录了。')
        navigate({ to: '/sign-in' })
      } else {
        await resetPassword({
          email,
          code: data.otp,
          new_password: (data as { newPassword: string }).newPassword,
        })
        toast.success('密码重置成功！现在可以登录了。')
        navigate({ to: '/sign-in' })
      }
    } catch (err) {
      const msg =
        (err as { response?: { data?: { error?: string; detail?: string } } })
          ?.response?.data?.error ??
        (err as { response?: { data?: { detail?: string } } })?.response?.data
          ?.detail ??
        '验证失败'
      toast.error(msg)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <Form {...form}>
      <form
        onSubmit={form.handleSubmit(onSubmit)}
        className={cn('grid gap-4', className)}
        {...props}
      >
        <FormField
          control={form.control}
          name='otp'
          render={({ field }) => (
            <FormItem>
              <FormLabel className='sr-only'>验证码</FormLabel>
              <FormControl>
                <InputOTP
                  maxLength={6}
                  {...field}
                  containerClassName='justify-between sm:[&>[data-slot="input-otp-group"]>div]:w-12'
                >
                  <InputOTPGroup>
                    <InputOTPSlot index={0} />
                    <InputOTPSlot index={1} />
                  </InputOTPGroup>
                  <InputOTPSeparator />
                  <InputOTPGroup>
                    <InputOTPSlot index={2} />
                    <InputOTPSlot index={3} />
                  </InputOTPGroup>
                  <InputOTPSeparator />
                  <InputOTPGroup>
                    <InputOTPSlot index={4} />
                    <InputOTPSlot index={5} />
                  </InputOTPGroup>
                </InputOTP>
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        {mode === 'reset-password' && (
          <FormField
            control={form.control}
            name='newPassword'
            render={({ field }) => (
              <FormItem>
                <FormLabel>新密码</FormLabel>
                <FormControl>
                  <PasswordInput placeholder='********' {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        )}

        <Button className='mt-2' disabled={otp.length < 6 || isLoading}>
          {isLoading ? '验证中...' : '验证'}
        </Button>
      </form>
    </Form>
  )
}
