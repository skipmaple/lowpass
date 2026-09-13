module Adapters
  class HackerNews < Base
    API = "https://hacker-news.firebaseio.com/v0"
    ALGOLIA = "https://hn.algolia.com/api/v1/search"

    def self.backfill?
      true
    end

    private
      def entries(period_key:)
        count = config.fetch(:count, 10).to_i
        min_score = config.fetch(:min_score, 0).to_i
        ids = JSON.parse(http("#{API}/#{config.fetch(:list, "top")}stories.json").body)
        picked = []
        ids.each do |id|
          break if picked.size >= count
          story = JSON.parse(http("#{API}/item/#{id}.json").body)
          next if story.nil?
          next unless story["type"] == "story" && story["score"].to_i >= min_score && !story["dead"] && !story["deleted"]
          picked << build(story, picked.size + 1)
        end
        picked
      end

      def build(story, rank)
        discussion = "https://news.ycombinator.com/item?id=#{story['id']}"
        Entry.new(
          title: story["title"],
          url: story["url"].presence || discussion,
          author: story["by"],
          published_at: Time.at(story["time"].to_i).utc,
          rank: rank,
          meta: { score: story["score"].to_i, comments: story["descendants"].to_i, comments_url: discussion }
        )
      end

      # 7.7 回填：Algolia 的 front_page 标签按该上海日的 UTC 秒区间查；多要几倍再按分数排，过滤最低分数
      def backfill_entries(date)
        from = date.in_time_zone(PeriodKey::ZONE).beginning_of_day.to_i
        count = config.fetch(:count, 10).to_i
        min_score = config.fetch(:min_score, 0).to_i
        query = URI.encode_www_form(tags: "front_page", numericFilters: "created_at_i>=#{from},created_at_i<#{from + 86_400}", hitsPerPage: [ count * 3, 100 ].min)
        hits = JSON.parse(http("#{ALGOLIA}?#{query}").body).fetch("hits")
        hits.select { |hit| hit["title"].present? && hit["points"].to_i >= min_score }
            .sort_by { |hit| -hit["points"].to_i }
            .first(count)
            .each_with_index.map { |hit, index| build_hit(hit, index + 1) }
      end

      def build_hit(hit, rank)
        discussion = "https://news.ycombinator.com/item?id=#{hit['objectID']}"
        Entry.new(
          title: hit["title"],
          url: hit["url"].presence || discussion,
          author: hit["author"],
          published_at: Time.at(hit["created_at_i"].to_i).utc,
          rank: rank,
          meta: { score: hit["points"].to_i, comments: hit["num_comments"].to_i, comments_url: discussion }
        )
      end
  end
end
