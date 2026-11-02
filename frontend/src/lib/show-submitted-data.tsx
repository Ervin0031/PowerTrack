import { toast } from 'sonner'

export function showSubmittedData(
  data: unknown,
  title: string = '您提交了以下内容：'
) {
  toast.message(title, {
    description: (
      <pre className='mt-2 w-full overflow-x-auto rounded-md bg-neutral-950 p-4'>
        <code className='text-white'>{JSON.stringify(data, null, 2)}</code>
      </pre>
    ),
  })
}
