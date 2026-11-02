import { Link, getRouteApi } from '@tanstack/react-router'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { AuthLayout } from '../auth-layout'
import { OtpForm } from './components/otp-form'

const route = getRouteApi('/(auth)/otp')

export function Otp() {
  const { email, mode } = route.useSearch()

  const title =
    mode === 'verify-email'
      ? '验证邮箱'
      : '重置密码'

  const description =
    mode === 'verify-email'
      ? `请输入发送至 ${email} 的验证码。`
      : `请输入发送至 ${email} 的验证码和新密码。`

  return (
    <AuthLayout>
      <Card className='max-w-md gap-4'>
        <CardHeader>
          <CardTitle className='text-base tracking-tight'>{title}</CardTitle>
          <CardDescription>{description}</CardDescription>
        </CardHeader>
        <CardContent>
          <OtpForm email={email} mode={mode} />
        </CardContent>
        <CardFooter>
          <p className='px-8 text-center text-sm text-muted-foreground'>
            没有收到验证码？{' '}
            <Link
              to='/sign-in'
              className='underline underline-offset-4 hover:text-primary'
            >
              重新发送验证码
            </Link>
          </p>
        </CardFooter>
      </Card>
    </AuthLayout>
  )
}
