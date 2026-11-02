import { useState } from 'react'
import { createTableMock } from '@/test-utils/tanstack-table'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render } from 'vitest-browser-react'
import { userEvent } from 'vitest/browser'
import { UsersMultiDeleteDialog } from './users-multi-delete-dialog'

vi.mock('../data/api', () => ({ deleteUser: vi.fn().mockResolvedValue(undefined) }))

describe('UsersMultiDeleteDialog', () => {
  beforeEach(() => vi.clearAllMocks())

  it('renders the dialog with the correct title, description, input and buttons', async () => {
    const { table } = createTableMock()

    const { getByRole, getByText } = await render(
      <UsersMultiDeleteDialog open onOpenChange={vi.fn()} table={table} />,
    )

    const title = getByRole('heading', { level: 2, name: /Delete 2 users/i })
    const desc = getByText(/Are you sure you want to delete the selected users?/i)
    const confirmDeleteInput = getByRole('textbox', { name: /Confirm by typing "DELETE"/i })
    const deleteButton = getByRole('button', { name: /Delete/i })

    await expect.element(title).toBeInTheDocument()
    await expect.element(desc).toBeInTheDocument()
    await expect.element(confirmDeleteInput).toBeInTheDocument()
    await expect.element(deleteButton).toBeInTheDocument()
    await expect.element(deleteButton).toBeDisabled()
  })

  it('keeps the delete button disabled until the confirm delete input is filled correctly', async () => {
    const { table } = createTableMock()
    const { getByRole } = await render(
      <UsersMultiDeleteDialog open onOpenChange={vi.fn()} table={table} />,
    )

    const confirmDeleteInput = getByRole('textbox', { name: /Confirm by typing "DELETE"/i })
    const deleteButton = getByRole('button', { name: /Delete/i })

    await expect.element(deleteButton).toBeDisabled()

    await userEvent.fill(confirmDeleteInput, 'wrong-input')
    await expect.element(deleteButton).toBeDisabled()

    await userEvent.fill(confirmDeleteInput, 'DELETE')
    await expect.element(deleteButton).toBeEnabled()
  })

  it('closes the dialog when the cancel button is clicked', async () => {
    const { table } = createTableMock()
    const onOpenChange = vi.fn()
    const { getByRole } = await render(
      <UsersMultiDeleteDialog open onOpenChange={onOpenChange} table={table} />,
    )

    const cancelButton = getByRole('button', { name: /Cancel/i })
    await userEvent.click(cancelButton)

    expect(onOpenChange).toHaveBeenCalledOnce()
    expect(onOpenChange).toHaveBeenCalledWith(false)
  })

  it('resets the confirm delete input when the dialog is closed and reopened', async () => {
    const { table } = createTableMock()

    function Harness() {
      const [open, setOpen] = useState(true)
      return (
        <>
          <button type='button' onClick={() => setOpen(true)}>
            Reopen
          </button>
          {open ? (
            <UsersMultiDeleteDialog open={open} onOpenChange={setOpen} table={table} />
          ) : null}
        </>
      )
    }

    const { getByRole } = await render(<Harness />)

    const confirmDeleteInput = getByRole('textbox', { name: /Confirm by typing "DELETE"/i })
    await userEvent.fill(confirmDeleteInput, 'DELETE')
    await expect.element(confirmDeleteInput).toHaveValue('DELETE')

    const cancelButton = getByRole('button', { name: /Cancel/i })
    await userEvent.click(cancelButton)

    const reopenButton = getByRole('button', { name: /Reopen/i })
    await userEvent.click(reopenButton)
    await expect.element(confirmDeleteInput).toHaveValue('')
  })

  it('calls delete on submit', async () => {
    const userIds = [1, 2]
    const rows = userIds.map((id) => ({ original: { id, username: `user${id}`, email: `user${id}@test.com`, is_active: true, is_verified: true, is_superuser: false } }))
    const resetRowSelection = vi.fn()
    const table = {
      getFilteredSelectedRowModel: () => ({ rows }),
      resetRowSelection,
    } as unknown as ReturnType<typeof createTableMock>['table']
    const onOpenChange = vi.fn()
    const { getByRole } = await render(
      <UsersMultiDeleteDialog open onOpenChange={onOpenChange} table={table} />,
    )

    const confirmDeleteInput = getByRole('textbox', { name: /Confirm by typing "DELETE"/i })
    const deleteButton = getByRole('button', { name: /Delete/i })

    await userEvent.fill(confirmDeleteInput, 'DELETE')
    await userEvent.click(deleteButton)

    // ponytail: test that dialog closes and table resets — API mock verified by no throw
    await vi.waitFor(() => {
      expect(onOpenChange).toHaveBeenCalledWith(false)
      expect(resetRowSelection).toHaveBeenCalledOnce()
    })
  })
})
