# 设置（5.6）：调度时间可改；白名单只读（R-5.5 由环境配置）。告警（③）与兴趣画像、模型供应商（④）往这一页加节
class Admin::SettingsController < Admin::BaseController
  KEYS = %w[ daily_time weekly_time ].freeze

  def show
    render inertia: "Admin/Settings/Show", props: { schedule: KEYS.index_with { |key| Setting.get(key) }, whitelist: Identity::Whitelist.emails }
  end

  def update
    schedule = schedule_params
    values = KEYS.index_with { |key| schedule[key] }
    errors = values.reject { |_, value| Setting.valid_time?(value) }.transform_values { [ "格式是 HH:MM" ] }
    if errors.any?
      redirect_to admin_settings_path, inertia: { errors: errors }
    else
      changes = values.filter_map { |key, value| [ key, [ Setting.get(key), value ] ] if Setting.get(key) != value }.to_h
      values.each { |key, value| Setting.set(key, value) }
      Audit.record("settings.update", "Setting#schedule", changes)
      redirect_to admin_settings_path, notice: "已保存"
    end
  end

  private
    # 表单两项一起提交：缺哪一项（连 schedule 整个都没有）都按校验错误回设置页，不是 400；
    # 形状不对（?schedule=x）同样落到校验，permit 直接把它滤掉
    def schedule_params
      params.permit(schedule: KEYS).fetch(:schedule, {})
    end
end
