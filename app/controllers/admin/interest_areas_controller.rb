# 兴趣画像（R-9.5、D18）：设置页里的一张表，行内改；校验句子进 flash（附录 B）
class Admin::InterestAreasController < Admin::BaseController
  def create
    area = InterestArea.new(area_params)
    area.sort_order = (InterestArea.maximum(:sort_order) || 0) + 1 if area.sort_order.nil? || area.sort_order.zero?
    save(area, "interest_area.create", "已保存 #{area.name}")
  end

  def update
    area = InterestArea.find(params[:id])
    area.assign_attributes(area_params)
    save(area, "interest_area.update", "已保存 #{area.name}")
  end

  def destroy
    area = InterestArea.find(params[:id])
    area.destroy!
    Audit.record("interest_area.destroy", "InterestArea##{area.id}", { name: area.name })
    redirect_to admin_settings_path, notice: "已删除 #{area.name}"
  end

  private
    def area_params
      params.fetch(:interest_area, {}).permit(:name, :keywords, :sort_order, :enabled)
    end

    def save(area, action, notice)
      if area.save
        Audit.record(action, "InterestArea##{area.id}", area.saved_changes.except("updated_at", "created_at"))
        redirect_to admin_settings_path, notice: notice
      else
        redirect_to admin_settings_path, alert: area.errors.map(&:message).uniq.join(" · ")
      end
    end
end
