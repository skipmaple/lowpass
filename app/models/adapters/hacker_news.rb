module Adapters
  class HackerNews < Base
    API = "https://hacker-news.firebaseio.com/v0"

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
  end
end
