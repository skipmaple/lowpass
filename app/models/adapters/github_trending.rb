module Adapters
  class GithubTrending < Base
    ParseError = Class.new(StandardError)

    private
      def entries(period_key:)
        languages = Array(config[:languages]).reject(&:blank?)
        if languages.empty?
          parse(fetch_page(nil)).first(config.fetch(:count, 10).to_i)
        else
          per = config.fetch(:count, 5).to_i
          languages.flat_map { |lang| parse(fetch_page(lang), language: lang).first(per) }.each_with_index.map { |e, i| e.rank = i + 1; e }
        end
      end

      def fetch_page(language)
        path = language ? "/trending/#{URI.encode_www_form_component(language)}" : "/trending"
        http("https://github.com#{path}?since=daily").body
      end

      def parse(html, language: nil)
        doc = Nokogiri::HTML(html)
        rows = doc.css("article.Box-row")
        raise ParseError, "no trending rows" if rows.empty?
        rows.each_with_index.map do |row, i|
          link = row.at_css("h2 a") or raise ParseError, "row without repo link"
          repo = link["href"].to_s.delete_prefix("/")
          Entry.new(
            title: repo,
            url: "https://github.com/#{repo}",
            summary: row.at_css("p")&.text,
            rank: i + 1,
            meta: {
              language: language || row.at_css("[itemprop='programmingLanguage']")&.text&.strip,
              stars: number(row.at_css("a[href$='/stargazers']")&.text),
              stars_today: number(row.css("span").map(&:text).find { |t| t.include?("stars today") })
            }
          )
        end
      end

      def number(text)
        text.to_s.delete(",").scan(/\d+/).first.to_i
      end
  end
end
