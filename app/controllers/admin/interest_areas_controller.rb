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
    # 形状不对（?interest_area=x）不能打成 500：认不出来就当没给，落到「必填」那条校验
    def area_params
      raw = params[:interest_area]
      raw.is_a?(ActionController::Parameters) ? raw.permit(:name, :keywords, :sort_order, :enabled) : {}
    end

    def save(area, action, notice)
      if area.save
        # 新建时 saved_changes 里也有 id：target 已经写了 InterestArea#<id>，payload 里那一对是噪音
        Audit.record(action, "InterestArea##{area.id}", area.saved_changes.except("id", "updated_at", "created_at"))
        redirect_to admin_settings_path, notice: notice
      else
        redirect_to admin_settings_path, alert: area.errors.map(&:message).uniq.join(" · ")
      end
    end
end
