# R-3.6 启停：POST 启用、DELETE 停用（停用的确认对话框在页面上）
class Admin::Sources::EnablementsController < Admin::BaseController
  before_action :set_source

  def create
    @source.update!(enabled: true)
    Audit.record("source.enable", "Source##{@source.id}")
    redirect_to admin_sources_path, notice: "已启用 #{@source.name}"
  end

  def destroy
    @source.update!(enabled: false)
    Audit.record("source.disable", "Source##{@source.id}")
    redirect_to admin_sources_path, notice: "已停用 #{@source.name}"
  end

  private
    def set_source
      @source = Source.find(params[:source_id])
    end
end
