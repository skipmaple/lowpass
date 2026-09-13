# 登录墙（D1）：默认每个动作都要登录，只有登录页、回调与失败页用 allow_unauthenticated_access 放行。
# 形状借 Rails 8 认证生成器 / fizzy：Session 记录 + 签名 cookie session_token。
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      token = cookies.signed[:session_token]
      return if token.blank?

      if session = Session.active.find_by(token: token)
        session.touch_last_seen!
        Rails.error.set_context(user_id: session.user_id)
        session
      else
        cookies.delete(:session_token)
        nil
      end
    end

    # R-5.7：GET 带上原地址回登录页，登录后回来；其他方法只回登录页
    def request_authentication
      if request.get? || request.head?
        redirect_to login_path(next: request.fullpath)
      else
        redirect_to login_path
      end
    end

    # next 只接受站内相对路径（R-5.7、AC-5.7）：单个 / 开头，第二个字符不是 / 或 \（协议相对地址），不含换行
    def safe_next(value)
      value if value.is_a?(String) && value.match?(%r{\A/(?![/\\])[^\r\n]*\z})
    end

    def start_session_for(user)
      user.sessions.create!.tap do |session|
        Current.session = session
        cookies.signed[:session_token] = { value: session.token, httponly: true, same_site: :lax,
                                           secure: Rails.env.production?, expires: session.expires_at }
      end
    end

    def terminate_session
      Current.session&.destroy
      Current.session = nil
      cookies.delete(:session_token)
    end
end
