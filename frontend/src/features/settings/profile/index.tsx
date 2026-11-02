import { ContentSection } from '../components/content-section'
import { ProfileForm } from './profile-form'

export function SettingsProfile() {
  return (
    <ContentSection
      title='个人资料'
      desc='其他用户将以此信息识别你。'
    >
      <ProfileForm />
    </ContentSection>
  )
}
