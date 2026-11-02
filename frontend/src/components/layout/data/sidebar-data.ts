import {
  Bell,
  Command,
  Dumbbell,
  Heart,
  LayoutDashboard,
  Monitor,
  Palette,
  Settings,
  UserCog,
  Users,
  Wrench,
} from 'lucide-react'
import { type SidebarData } from '../types'

export const sidebarData: SidebarData = {
  user: {
    name: 'User',
    email: '',
    avatar: '',
  },
  teams: [
    {
      name: 'PowerTrack',
      logo: Command,
      plan: '管理员',
    },
  ],
  navGroups: [
    {
      title: '概览',
      items: [
        {
          title: '仪表盘',
          url: '/',
          icon: LayoutDashboard,
        },
        {
          title: '用户管理',
          url: '/users',
          icon: Users,
        },
      ],
    },
    {
      title: '训练',
      items: [
        {
          title: '动作列表',
          url: '/exercises',
          icon: Dumbbell,
        },
        {
          title: '器械管理',
          url: '/exercises/equipment',
          icon: Wrench,
        },
        {
          title: '肌群管理',
          url: '/exercises/muscle-groups',
          icon: Heart,
        },
      ],
    },
    {
      title: '设置',
      items: [
        {
          title: '设置',
          icon: Settings,
          items: [
            {
              title: '个人资料',
              url: '/settings',
              icon: UserCog,
            },
            {
              title: '账号',
              url: '/settings/account',
              icon: Wrench,
            },
            {
              title: '外观',
              url: '/settings/appearance',
              icon: Palette,
            },
            {
              title: '通知',
              url: '/settings/notifications',
              icon: Bell,
            },
            {
              title: '显示',
              url: '/settings/display',
              icon: Monitor,
            },
          ],
        },
      ],
    },
  ],
}
