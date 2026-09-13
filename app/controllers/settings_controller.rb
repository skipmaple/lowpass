# 个人设置页（R-5.10）：只读展示，唯一的动作是登出（DELETE /session）。绑定方式只列真实 provider，developer 不列。
class SettingsController < ApplicationController
  def show
    render inertia: "Settings/Show", props: { user: user_props, identities: identity_props, session: session_props }.merge(footer_props)
  end

  private
    def user_props
      user = Current.user
      { display_name: user.display_name, email: user.email, avatar_url: user.avatar_url, role: user.role }
    end

    # 按登录页的顺序列 provider；未绑定的给 nil，页面据此画「使用 X 登录」的表单（走 R-5.3 的合并规则）
    def identity_props
      bound = Current.user.auth_identities.index_by(&:provider)
      Rails.configuration.x.auth_providers.filter_map do |strategy|
        provider = Identity::Profile::STRATEGIES.fetch(strategy)
        next if provider == "developer"

        { provider: provider, strategy: strategy, linked_at_label: bound[provider]&.linked_at&.then { |time| stamp(time) } }
      end
    end

    def session_props
      session = Current.session
      { logged_in_label: stamp(session.created_at), expires_label: session.expires_at.in_time_zone(PeriodKey::ZONE).strftime("%Y-%m-%d") }
    end

    # 元数据里的时间写成数字（设计口味）：2026-09-08 14:02，按上海时区
    def stamp(time)
      time.in_time_zone(PeriodKey::ZONE).strftime("%Y-%m-%d %H:%M")
    end
end
