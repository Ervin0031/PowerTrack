import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, type RenderResult } from 'vitest-browser-react'
import { userEvent, type Locator } from 'vitest/browser'
import { ForgotPasswordForm } from './forgot-password-form'

const navigateMock = vi.fn()
const forgotPasswordMock = vi.fn(() => Promise.resolve())

vi.mock('@/features/auth/data/api', () => ({
  forgotPassword: (...args: unknown[]) => forgotPasswordMock(...args),
}))

vi.mock('@tanstack/react-router', async (orig) => {
  const actual = await orig<typeof import('@tanstack/react-router')>()
  return { ...actual, useNavigate: () => navigateMock }
})

describe('ForgotPasswordForm', () => {
  let screen: RenderResult
  let emailInput: Locator
  let continueButton: Locator

  beforeEach(async () => {
    vi.clearAllMocks()

    screen = await render(<ForgotPasswordForm />)
    emailInput = screen.getByRole('textbox', { name: /^Email$/i })
    continueButton = screen.getByRole('button', { name: /^Continue$/i })
  })

  it('renders email field and continue button', async () => {
    await expect.element(emailInput).toBeInTheDocument()
    await expect.element(continueButton).toBeInTheDocument()
  })

  it('shows validation when submitting empty form', async () => {
    await userEvent.click(continueButton)
    await expect
      .element(screen.getByText(/^Please enter your email\.$/i))
      .toBeInTheDocument()
  })

  it('calls forgotPassword and navigates to OTP on success', async () => {
    await userEvent.fill(emailInput, 'a@b.com')
    await userEvent.click(continueButton)

    await vi.waitFor(() => expect(forgotPasswordMock).toHaveBeenCalledOnce())
    expect(forgotPasswordMock).toHaveBeenCalledWith({ email: 'a@b.com' })

    await vi.waitFor(() =>
      expect(navigateMock).toHaveBeenCalledWith({
        to: '/otp',
        search: { email: 'a@b.com', mode: 'reset-password' },
      }),
    )

    // Form should reset on success
    await expect.element(emailInput).toHaveValue('')
  })
})
