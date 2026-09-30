# 注销（R-5.11、D26）：设置页的确认框确认之后删掉当前用户。登录身份与会话跟着删，别的设备上的会话一并作废；
# 审计记录留着、操作者置空；期与条目不碰（都在 User 与外键上）。删完像登出一样清掉 cookie，回登录页
class UsersController < ApplicationController
  DELETED = "已注销账号。"

  def destroy
    Current.user.destroy!
    terminate_session
    redirect_to login_path, notice: DELETED
  end
end
