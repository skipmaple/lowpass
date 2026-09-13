# 每种适配器的配置项（PRD R-3.2）：字段、类型、范围、默认值。归一化把表单里的字符串转成该有的类型，
# 校验把错误挂到 source.errors 的 config.<字段> 上，后台表单据字段名放到对应输入框下。
class Source::Config
  LANGUAGE = /\A[A-Za-z0-9+#.\- ]{1,40}\z/

  SCHEMAS = {
    "hacker_news" => { publications: %w[ daily ], fields: {
      "list" => { type: :enum, values: %w[ top best ], default: "top" },
      "count" => { type: :integer, range: 1..100, default: 10 },
      "min_score" => { type: :integer, range: 0.., default: 0 }
    } },
    "github_trending" => { publications: %w[ daily ], fields: {
      "languages" => { type: :list, max: 3, item: LANGUAGE, default: [] },
      "count" => { type: :integer, range: 1..25, default: 10 }
    } },
    "rss" => { publications: %w[ daily weekly ], fields: {
      "feed_url" => { type: :url, required: true },
      "count" => { type: :integer, range: 1..50, default: 10 },
      "window_hours" => { type: :integer, range: 1..72, default: 24, only: "daily" }
    } },
    "ruanyf_weekly" => { publications: %w[ weekly ], fields: {
      "min_items" => { type: :integer, range: 1.., default: 5 }
    } }
  }.freeze

  LABELS = { "list" => "榜单", "count" => "条数", "min_score" => "最低分数", "languages" => "语言列表",
             "feed_url" => "feed 地址", "window_hours" => "时间窗口（小时）", "min_items" => "最少条目阈值" }.freeze

  attr_reader :publications

  def self.for(adapter)
    new(SCHEMAS.fetch(adapter))
  end

  def initialize(schema)
    @publications = schema.fetch(:publications)
    @fields = schema.fetch(:fields)
  end

  # 该刊物适用的字段名（RSS 的时间窗口只有日刊有）
  def fields(publication)
    @fields.reject { |_, spec| spec[:only] && spec[:only] != publication }.keys
  end

  def normalize(raw, publication)
    raw = (raw || {}).to_h.stringify_keys
    fields(publication).each_with_object({}) do |name, config|
      spec = @fields.fetch(name)
      value = coerce(spec, raw[name])
      config[name] = value.nil? ? spec[:default] : value
    end
  end

  def validate(config, publication, errors)
    fields(publication).each do |name|
      spec = @fields.fetch(name)
      message = problem(spec, config[name])
      errors.add(:"config.#{name}", message) if message
    end
  end

  private
    def coerce(spec, value)
      case spec[:type]
      when :integer then Integer(value.to_s.strip, 10, exception: false)
      when :list then Array(value.is_a?(String) ? value.split(",") : value).map { |item| item.to_s.strip }.reject(&:empty?)
      else value.to_s.strip.presence
      end
    end

    def problem(spec, value)
      case spec[:type]
      when :integer then range_problem(spec[:range], value)
      when :enum then "只能是 #{spec[:values].join(" 或 ")}" unless spec[:values].include?(value)
      when :list then list_problem(spec, value)
      when :url then url_problem(spec, value)
      end
    end

    def range_problem(range, value)
      return if value.is_a?(Integer) && range.cover?(value)

      range.end ? "#{range.begin} 到 #{range.end}" : "不小于 #{range.begin}"
    end

    def list_problem(spec, value)
      if value.size > spec[:max]
        "最多 #{spec[:max]} 个"
      elsif value.any? { |item| !item.match?(spec[:item]) }
        "语言名只能有字母、数字与 + # . -"
      end
    end

    def url_problem(spec, value)
      if value.blank?
        "必填" if spec[:required]
      else
        uri = URI.parse(value)
        "要是 http(s) 地址" unless uri.is_a?(URI::HTTP) && uri.host.present?
      end
    rescue URI::InvalidURIError
      "要是 http(s) 地址"
    end
end
