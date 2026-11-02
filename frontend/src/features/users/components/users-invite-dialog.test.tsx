import { useState } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render } from 'vitest-browser-react'
import { userEvent } from 'vitest/browser'
import { UsersInviteDialog } from './users-invite-dialog'

// ponytail: invite has no backend endpoint, dialog shows toast.info
vi.mock('sonner', () => ({ toast: { info: vi.fn() } }))

describe('UsersInviteDialog', () => {
  beforeEach(() => vi.clearAllMocks())

  it('renders the dialog title and description', async () => {
    const { getByRole, getByText } = await render(
      <UsersInviteDialog open onOpenChange={vi.fn()} />,
    )

    const title = getByRole('heading', { level: 2, name: /Invite User/i })
    const desc = getByText(/Invite new user to join your team/i)

    await expect.element(title).toBeInTheDocument()
    await expect.element(desc).toBeInTheDocument()
  })

  it('closes when Cancel is clicked', async () => {
    const onOpenChange = vi.fn()
    const { getByRole } = await render(
      <UsersInviteDialog open onOpenChange={onOpenChange} />,
    )

    const cancelButton = getByRole('button', { name: /Cancel/i })
    await userEvent.click(cancelButton)

    expect(onOpenChange).toHaveBeenCalledOnce()
    expect(onOpenChange).toHaveBeenCalledWith(false)
  })

  it('shows error message when submitting empty form', async () => {
    const onOpenChange = vi.fn()
    const { getByRole, getByText } = await render(
      <UsersInviteDialog open onOpenChange={onOpenChange} />,
    )

    const emailErrorMessage = getByText(/Please enter a valid email./i)

    const submitButton = getByRole('button', { name: /Invite/i })
    await userEvent.click(submitButton)

    await expect.element(emailErrorMessage).toBeInTheDocument()
  })

  it('resets entered values when the dialog is closed and reopened', async () => {
    function Harness() {
      const [open, setOpen] = useState(true)
      return (
        <>
          <button type='button' onClick={() => setOpen(true)}>
            Reopen
          </button>
          <UsersInviteDialog open={open} onOpenChange={setOpen} />
        </>
      )
    }

    const { getByRole } = await render(<Harness />)

    const EMAIL_VALUE = 'test@example.com'
    const DESC_VALUE = 'This is a test description'

    const emailInput = getByRole('textbox', { name: /Email/i })
    await userEvent.fill(emailInput, EMAIL_VALUE)

    const descInput = getByRole('textbox', { name: /Description/i })
    await userEvent.fill(descInput, DESC_VALUE)

    await expect.element(emailInput).toHaveValue(EMAIL_VALUE)
    await expect.element(descInput).toHaveValue(DESC_VALUE)

    const cancelButton = getByRole('button', { name: /Cancel/i })
    await userEvent.click(cancelButton)

    const reopenButton = getByRole('button', { name: /Reopen/i })
    await userEvent.click(reopenButton)

    await expect.element(emailInput).toHaveValue('')
    await expect.element(descInput).toHaveValue('')
  })
})
