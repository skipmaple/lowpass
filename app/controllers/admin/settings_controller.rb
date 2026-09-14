# 设置（5.6）：调度时间可改；白名单只读（R-5.5 由环境配置）。告警渠道状态与测试告警（③）在这一页；兴趣画像、模型供应商（④）往这一页加节
class Admin::SettingsController < Admin::BaseController
  KEYS = %w[ daily_time weekly_time ].freeze
  MODEL_KEYS = { "base_url" => "model_base_url", "model_name" => "model_name", "input_price" => "model_input_price",
                 "output_price" => "model_output_price", "monthly_cap" => "model_monthly_cap" }.freeze
  NUMBER_KEYS = %w[ input_price output_price monthly_cap ].freeze
  NUMBER = /\A\d+(\.\d+)?\z/
  MAX_LENGTH = 255             # settings.value 是 varchar(255)

  def show
    render inertia: "Admin/Settings/Show", props: {
      schedule: KEYS.index_with { |key| Setting.get(key) }, whitelist: Identity::Whitelist.emails, alerts: Alerts::Config.status_props,
      reasons: Reasons::Status.props, interest_areas: InterestArea.ordered.map { |a| { id: a.id, name: a.name, keywords: a.keywords, sort_order: a.sort_order, enabled: a.enabled } }
    }
  end

  def update
    params.key?(:model) ? update_model : update_schedule
  end

  private
    def update_schedule
      # 表单两项一起提交：缺哪一项（连 schedule 整个都没有）都按校验错误回设置页，不是 400；
      # 形状不对（?schedule=x）同样落到校验，permit 直接把它滤掉
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

    def schedule_params
      params.permit(schedule: KEYS).fetch(:schedule, {})
    end

    # 模型配置（R-9.9、D23）：地址 https（本机 http 也行）、数字不小于 0；地址与模型名都留空 = 未配置
    def update_model
      given = params.permit(model: MODEL_KEYS.keys).fetch(:model, {})
      values = MODEL_KEYS.keys.index_with { |key| given[key].to_s.strip }
      errors = model_errors(values)
      if errors.any?
        redirect_to admin_settings_path, inertia: { errors: errors }
      else
        changes = values.filter_map { |key, value| [ key, [ Setting.get(MODEL_KEYS[key]), value ] ] if Setting.get(MODEL_KEYS[key]) != value }.to_h
        values.each { |key, value| Setting.set(MODEL_KEYS[key], value) }
        Audit.record("settings.update", "Setting#model", changes)
        redirect_to admin_settings_path, notice: "已保存"
      end
    end

    # 一个字段只报最要紧的那一条：先是长度（超了进不了库，别的都不用谈），再是地址与数字格式；
    # 数字字段空着是没填，不是填错了
    def model_errors(values)
      errors = values.select { |_, value| value.length > MAX_LENGTH }.transform_values { [ "最多 #{MAX_LENGTH} 字" ] }
      errors["base_url"] ||= [ "地址必须是 https" ] if values["base_url"].present? && !Reasons::Provider.valid_base_url?(values["base_url"])
      NUMBER_KEYS.each { |key| errors[key] ||= [ values[key].blank? ? "必填" : "不小于 0" ] unless values[key].match?(NUMBER) }
      errors
    end
end
