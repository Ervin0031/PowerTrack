import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render } from 'vitest-browser-react'
import { userEvent } from 'vitest/browser'
import { type User } from '../data/schema'
import { UsersActionDialog } from './users-action-dialog'

const VALIDATION_MESSAGES = {
  username: 'Username is required.',
  email: 'Valid email is required.',
  password: 'Password is required.',
  passwordMismatch: "Passwords don't match.",
  passwordLength: 'Password must be at least 8 characters long.',
  passwordNumber: 'Password must contain at least one number.',
  passwordLowercase: 'Password must contain at least one lowercase letter.',
} as const

const MOCK_USER: User = {
  id: 1,
  username: 'alex_smith',
  email: 'alex@smith.com',
  is_active: true,
  is_verified: true,
  is_superuser: true,
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-02-02T00:00:00Z',
  last_login_at: null,
}

vi.mock('../data/api', () => ({ updateUser: vi.fn().mockResolvedValue({}) }))

describe('UsersActionDialog', () => {
  beforeEach(() => vi.clearAllMocks())

  describe('add user', () => {
    it('renders title and description', async () => {
      const { getByRole, getByText } = await render(
        <UsersActionDialog open onOpenChange={vi.fn()} />,
      )

      const title = getByRole('heading', { level: 2, name: /Add New User/i })
      const description = getByText(/Create new user here. Click save when you're done./i)

      await expect.element(title).toBeInTheDocument()
      await expect.element(description).toBeInTheDocument()
    })

    it('shows validation messages when the form is submitted with empty fields', async () => {
      const { getByRole, getByText } = await render(
        <UsersActionDialog open onOpenChange={vi.fn()} />,
      )

      const submitButton = getByRole('button', { name: /Save Changes/i })
      await userEvent.click(submitButton)

      await expect.element(getByText(VALIDATION_MESSAGES.username)).toBeInTheDocument()
      await expect.element(getByText(VALIDATION_MESSAGES.email)).toBeInTheDocument()
      await expect.element(getByText(VALIDATION_MESSAGES.password)).toBeInTheDocument()
    })

    it('keeps confirm password disabled until password field is touched', async () => {
      const { getByRole } = await render(
        <UsersActionDialog open onOpenChange={vi.fn()} />,
      )

      const password = getByRole('textbox', { name: /^Password$/i })
      const confirmPassword = getByRole('textbox', { name: /Confirm Password/i })
      await expect.element(confirmPassword).toBeDisabled()

      await userEvent.type(password, 'a')
      await expect.element(confirmPassword).toBeEnabled()
    })

    it('shows password validation messages when password is invalid', async () => {
      const { getByRole, getByText } = await render(
        <UsersActionDialog open onOpenChange={vi.fn()} />,
      )

      const password = getByRole('textbox', { name: /^Password$/i })
      const confirmPassword = getByRole('textbox', { name: /Confirm Password/i })
      await userEvent.type(password, 'a')
      await userEvent.type(confirmPassword, 'b')
      const submitButton = getByRole('button', { name: /Save Changes/i })

      await userEvent.click(submitButton)

      await expect.element(getByText(VALIDATION_MESSAGES.passwordMismatch)).toBeInTheDocument()

      await userEvent.fill(password, 'short')
      await expect.element(getByText(VALIDATION_MESSAGES.passwordLength)).toBeInTheDocument()

      await userEvent.fill(password, 'ONLYUPPERCASE')
      await expect.element(getByText(VALIDATION_MESSAGES.passwordLowercase)).toBeInTheDocument()

      await userEvent.fill(password, 'onlylowercase')
      await expect.element(getByText(VALIDATION_MESSAGES.passwordNumber)).toBeInTheDocument()

      await userEvent.fill(password, 'S3cur3P@ssw0rd')
      await userEvent.fill(confirmPassword, 'S3cur3P@ssw0rd')

      await expect.element(getByText(VALIDATION_MESSAGES.passwordMismatch)).not.toBeInTheDocument()
      await expect.element(getByText(VALIDATION_MESSAGES.passwordLength)).not.toBeInTheDocument()
      await expect.element(getByText(VALIDATION_MESSAGES.passwordNumber)).not.toBeInTheDocument()
    })
  })

  describe('edit user', () => {
    it('renders title and description', async () => {
      const { getByRole, getByText } = await render(
        <UsersActionDialog open onOpenChange={vi.fn()} currentRow={MOCK_USER} />,
      )

      const title = getByRole('heading', { level: 2, name: /Edit User/i })
      const description = getByText(/Update the user here\. Click save when you're done\./i)

      await expect.element(title).toBeInTheDocument()
      await expect.element(description).toBeInTheDocument()
    })

    it('requires confirm password when password is changed', async () => {
      const { getByRole, getByText } = await render(
        <UsersActionDialog open onOpenChange={vi.fn()} currentRow={MOCK_USER} />,
      )

      const password = getByRole('textbox', { name: /^Password$/i })
      const confirmPassword = getByRole('textbox', { name: /Confirm Password/i })

      await userEvent.fill(password, 'S3cur3P@ssw0rd')
      await expect.element(confirmPassword).toBeEnabled()

      const submitButton = getByRole('button', { name: /Save Changes/i })
      await userEvent.click(submitButton)

      await expect.element(getByText(VALIDATION_MESSAGES.passwordMismatch)).toBeInTheDocument()
    })
  })
})
