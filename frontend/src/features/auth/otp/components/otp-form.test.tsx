import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { render, type RenderResult } from 'vitest-browser-react'
import { type Locator, userEvent } from 'vitest/browser'
import { OtpForm } from './otp-form'

const navigate = vi.fn()
const verifyEmailMock = vi.fn(() => Promise.resolve())

vi.mock('@/features/auth/data/api', () => ({
  verifyEmail: (...args: unknown[]) => verifyEmailMock(...args),
  resetPassword: vi.fn(() => Promise.resolve()),
}))

vi.mock('@tanstack/react-router', async (orig) => {
  const actual = await orig<typeof import('@tanstack/react-router')>()
  return { ...actual, useNavigate: () => navigate }
})

describe('OtpForm', () => {
  let screen: RenderResult
  let otpInput: Locator
  let verifyButton: Locator

  beforeEach(async () => {
    vi.clearAllMocks()

    screen = await render(
      <OtpForm email='test@example.com' mode='verify-email' />,
    )
    otpInput = screen.getByLabelText(/^Verification Code$/i)
    verifyButton = screen.getByRole('button', { name: /^Verify$/i })
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('disables Verify until 6 digits are entered', async () => {
    await expect.element(verifyButton).toBeDisabled()

    await userEvent.fill(otpInput, '12345')
    await expect.element(verifyButton).toBeDisabled()

    await userEvent.fill(otpInput, '123456')
    await expect.element(verifyButton).toBeEnabled()
  })

  it('submits the OTP, calls verifyEmail, and navigates to sign-in', async () => {
    await userEvent.fill(otpInput, '123456')
    await userEvent.click(verifyButton)

    await vi.waitFor(() => expect(verifyEmailMock).toHaveBeenCalledOnce())
    expect(verifyEmailMock).toHaveBeenCalledWith({
      email: 'test@example.com',
      code: '123456',
    })

    await vi.waitFor(() =>
      expect(navigate).toHaveBeenCalledWith({ to: '/sign-in' }),
    )
  })
})
