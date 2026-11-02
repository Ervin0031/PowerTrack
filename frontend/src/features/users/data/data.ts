import { Shield, UserCheck } from 'lucide-react'

// ponytail: backend has is_active boolean, not 4 statuses
export const statusTypes = new Map<boolean, string>([
  [true, 'bg-primary/10 text-primary border-primary/20'],
  [false, 'bg-muted text-muted-foreground border-muted'],
])

// ponytail: backend has is_superuser boolean, not 4 roles
export const roleTypes = [
  { label: '超级管理员', value: true, icon: Shield },
  { label: '普通用户', value: false, icon: UserCheck },
] as const
