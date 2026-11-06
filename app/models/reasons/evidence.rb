# 只为理由补充条目原文的一手依据：读取当前链接，不遍历链接、不执行脚本、不改已发布条目。
# HTTP 安全边界沿用源抓取层，不能使用模型端点允许 localhost 的例外。
class Reasons::Evidence
  Result = Data.define(:text, :url, :error)
  TIMEOUT = 20
  MAX_BYTES = 2.megabytes
  MAX_CHARACTERS = 12_000
  MIN_BODY_CHARACTERS = 80
  CVE_ID = /\ACVE-(\d{4})-(\d{5,})\z/
  NOISE = "script, style, nav, aside, form, header, footer, iframe, object, embed, svg, canvas, noscript, template, [hidden], [inert], [aria-hidden='true'], #comments, .comments, .comment, .comment-tree".freeze
  HEADINGS = "h1, h2, h3, h4, h5, h6".freeze
  BLOCKS = "p, div, section, li, pre, blockquote, tr, #{HEADINGS}".freeze

  def self.fetch(item)
    new(item.url, title: item.title).fetch
  end

  def initialize(url, title:)
    @url = url
    @title = title
  end

  def fetch
    uri = URI(@url)
    if uri.is_a?(URI::HTTPS) && uri.port == 443 && uri.host.to_s.downcase.in?(%w[ cve.org www.cve.org ]) && uri.path == "/CVERecord"
      ids = URI.decode_www_form(uri.query.to_s).select { |key, _| key == "id" }.map(&:last)
      match = ids.sole.match(CVE_ID) if ids.one?
      return insufficient("CVE 编号格式暂不支持") unless match

      @cve_id = ids.sole
      # CVE 前端依赖 JavaScript；固定映射到官方同一记录，不使用页面提供的任意下载地址。
      @url = "https://raw.githubusercontent.com/CVEProject/cvelistV5/main/cves/#{match[1]}/#{match[2][0...-3]}xxx/#{@cve_id}.json"
    end

    # Http 的 read_timeout 是两次读取之间的上限；外层还限制解析和整条重定向链的总耗时。
    Timeout.timeout(TIMEOUT) do
      response = Adapters::Http.get(@url, timeout: TIMEOUT, max_bytes: MAX_BYTES)
      body = response.body.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      content_type = response.content_type.to_s.split(";").first.to_s.strip.downcase
      if @cve_id
        extract_cve(body)
      elsif content_type.in?(%w[ text/plain text/markdown ])
        result(normalize(body))
      elsif content_type.in?(%w[ text/html application/xhtml+xml ]) || (content_type.empty? && body.match?(/<(?!!--)[a-z!]/i))
        extract_html(body)
      else
        insufficient("暂不支持此内容格式")
      end
    end
  rescue Timeout::Error
    failure("连接超时")
  rescue Adapters::Http::Error => e
    failure(Adapters::Failure.reason(e))
  rescue URI::Error
    failure("原文地址无效")
  rescue Nokogiri::XML::SyntaxError, EncodingError, JSON::ParserError
    insufficient("无法解析可用正文")
  end

  private
    def extract_cve(body)
      record = JSON.parse(body)
      metadata = record["cveMetadata"] if record.is_a?(Hash)
      unless metadata.is_a?(Hash) && metadata["cveId"] == @cve_id && metadata["state"] == "PUBLISHED"
        return insufficient("CVE 记录未公开或编号不匹配")
      end

      containers = record["containers"]
      cna = containers["cna"] if containers.is_a?(Hash)
      return insufficient("CVE 记录缺少正文") unless cna.is_a?(Hash)

      descriptions = records(cna["descriptions"]).filter_map { |entry| entry["value"].presence if entry["value"].is_a?(String) }.first(6)
      return insufficient("CVE 记录缺少正文") if descriptions.empty?

      parts = [ "CVE：#{@cve_id}", *descriptions ]
      records(cna["affected"]).first(8).each do |entry|
        affected = fields(entry, %w[ vendor product ])
        versions = records(entry["versions"]).first(8).map { |version| fields(version, %w[ version versionType lessThan lessThanOrEqual status ]) }.reject(&:empty?)
        affected["versions"] = versions if versions.any?
        parts << "受影响产品：#{affected.to_json}" if affected.any?
      end
      records(cna["metrics"]).first(4).each do |entry|
        %w[ cvssV4_0 cvssV3_1 cvssV3_0 cvssV2_0 ].each do |version|
          next unless entry[version].is_a?(Hash)

          metric = fields(entry[version], %w[ baseScore baseSeverity vectorString ])
          parts << "#{version}：#{metric.to_json}" if metric.any?
        end
      end
      result(normalize(parts.join("\n")))
    end

    def records(value)
      value.is_a?(Array) ? value.select { |entry| entry.is_a?(Hash) } : []
    end

    def fields(record, keys)
      record.slice(*keys).select { |_, value| value.is_a?(String) || value.is_a?(Numeric) }
            .transform_values { |value| value.is_a?(String) ? value[0, 300] : value }
    end

    def extract_html(body)
      document = Nokogiri::HTML(body, nil, "UTF-8")
      javascript_shell = document.css("noscript").text.match?(/javascript/i)
      document.css(NOISE).remove
      document.xpath("//comment()").remove
      document.css("[style]").each do |node|
        node.remove if node["style"].match?(/(?:display\s*:\s*none|visibility\s*:\s*hidden)\b/i)
      end
      remove_comment_panels(document)

      root = article_root(document)
      if root && body_text(root).length >= MIN_BODY_CHARACTERS
        root.css("br").each { |node| node.replace("\n") }
        root.css(BLOCKS).each { |node| node.add_next_sibling("\n") }
        result(normalize(root.text))
      elsif javascript_shell
        insufficient("页面需要 JavaScript，未获取到正文")
      else
        insufficient("未提取到可用正文")
      end
    end

    def remove_comment_panels(document)
      document.css(".accordion .a-container").each do |container|
        controls = container.element_children
        label = controls.find { |node| node["class"].to_s.split.include?("a-btn") }
        panel = controls.find { |node| node["class"].to_s.split.include?("a-panel") }
        # 没有语义 id 的折叠评论仍需排除；同时核对入口文字与面板，不能删掉正文的所有 accordion。
        if label && panel && normalize(label.text).match?(/\A(?:(?:view|show|read)\s+)?comments?(?:\s*\(\d+\))?\z/i)
          container.remove
        end
      end
    end

    def article_root(document)
      if URI(@url).host.to_s.downcase == "github.com"
        select_article(document.css("article.markdown-body, #readme article, #readme .markdown-body"))
      else
        mains = document.css("main, [role='main']")
        scope = mains.one? ? mains.first : document
        articles = scope.css("article")
        if articles.empty? && mains.one?
          scope
        else
          select_article(articles)
        end
      end
    end

    def select_article(nodes)
      articles = nodes.reject { |node| node.ancestors("article").any? }
      return articles.first if articles.one?

      # 更新日志不能按长度猜，也不能把命中小节所在的整期公告当作同一条目的依据。
      words = title_words(@title)
      return if words.size < 2

      matches = articles.flat_map do |article|
        matching_headings(article, words).map { |heading| [ article, heading ] }
      end
      if matches.one?
        article, heading = matches.first
        article_section(article, heading)
      end
    end

    def matching_headings(article, words)
      parents = []
      article.css(HEADINGS).select do |heading|
        parents.pop while parents.any? && parents.last.name >= heading.name
        context = title_words(parents.map(&:text).join(" "))
        matches = (words - context).any? && (words - context - title_words(heading.text)).empty?
        parents << heading
        matches
      end
    end

    def article_section(article, heading)
      copy = article.dup
      heading = copy.css(HEADINGS)[article.css(HEADINGS).index(heading)]
      nodes = copy.xpath(".//node()").to_a
      start = nodes.index(heading)
      finish = nodes.each_index.find { |index| index > start && nodes[index].element? && nodes[index].name.match?(/\Ah[1-6]\z/) && nodes[index].name <= heading.name }
      # 保留祖先容器，但裁掉范围外的节点；这样下一小节即使换了容器也不会漏进来。
      retained = (nodes[start...finish] + heading.ancestors.to_a).to_set
      nodes.each { |node| node.remove unless retained.include?(node) }
      copy
    end

    def title_words(text)
      text.to_s.unicode_normalize(:nfkc).downcase.scan(/[[:alnum:]]+/).uniq
    end

    def body_text(node)
      copy = node.dup
      copy.css(HEADINGS).remove
      normalize(copy.text)
    end

    def normalize(text)
      text.lines.map { |line| line.gsub(/[[:space:]]+/, " ").strip }.reject(&:empty?).join("\n")
    end

    def result(text)
      if text.length >= MIN_BODY_CHARACTERS
        Result.new(text: text[0, MAX_CHARACTERS], url: @url, error: nil)
      else
        insufficient("未提取到可用正文")
      end
    end

    def insufficient(message)
      Result.new(text: nil, url: @url, error: "原文资料不足：#{message}")
    end

    def failure(message)
      Result.new(text: nil, url: @url, error: "原文获取失败：#{message}")
    end
end
