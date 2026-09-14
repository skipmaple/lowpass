# 登录、登出与登录失败（PRD 5.5，设计 4.4）。/auth/:provider 的发起与回调前半段在 OmniAuth 中间件里；
# 到 create 时 request.env["omniauth.auth"] 已经是 provider 给的资料。
class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create, :failure ]
  before_action :redirect_signed_in, only: :new

  UNMERGEABLE = "这个邮箱无法自动合并。如果你之前用其他方式登录过，请改用原方式。"
  CANCELLED = "已取消登录。"
  FAILED = "登录失败，请重试。"

  def new
    render inertia: "Login/Show", props: { providers: Rails.configuration.x.auth_providers, next: safe_next(params[:next]) }
  end

  def create
    # 这个环境没挂这条策略（比如生产的 /auth/developer/callback）：OmniAuth 不接这条回调，
    # 请求直接落到这里，env["omniauth.auth"] 是空的。当登录失败处理，不建会话
    if request.env["omniauth.auth"].nil?
      # provider 是路由通配段、已经解码过，inspect 一下再记：不然 /auth/a%0Ab/callback 能伪造一行日志
      Rails.logger.info { "登录失败：no_auth（#{params[:provider].inspect}）" }
      return redirect_to login_path, alert: FAILED
    end

    # 发起时表单里的 origin 由 OmniAuth 存进会话、回调时交回；开发登录直接 GET 回调，origin 在参数里。
    # 下面要换会话，先把它取到手上
    origin = request.env["omniauth.origin"].presence || params[:origin]

    begin
      result = Identity::Resolution.call(request.env["omniauth.auth"])
    rescue StandardError => e
      # R-5.8：匹配与合并这一步炸了（唯一键撞车、校验不过）也只说「登录失败，请重试」，原因进错误上报，不建会话
      Rails.error.report(e, handled: true)
      return redirect_to login_path, alert: FAILED
    end

    # 登录这一刻换掉会话 id（D11 的会话固定）：登录前那把可能是别人塞给读者的
    reset_session
    start_session_for(result.user)

    if result.outcome == :unmergeable
      redirect_to settings_path, alert: UNMERGEABLE
    else
      redirect_to safe_next(origin) || root_path, allow_other_host: false
    end
  end

  # R-5.8：取消显示「已取消登录」；其余（state 不符、回调异常）一律「登录失败，请重试」，原因只进日志
  def failure
    type = request.env["omniauth.error.type"]
    Rails.logger.info { "登录失败：#{type}（#{request.env["omniauth.error"]&.class}）" }
    redirect_to login_path, alert: type == :access_denied ? CANCELLED : FAILED
  end

  def destroy
    terminate_session
    redirect_to login_path
  end

  private
    def redirect_signed_in
      redirect_to root_path if resume_session
    end
end
