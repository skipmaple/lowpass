# PRD 3：首次部署时预置这 4 个源。每个环境都要（生产靠它开张，测试靠它验这份种子还能跑），
# find_or_create_by! 保证重复执行不多写一行、也不覆盖管理员改过的配置。
[
  { name: "Hacker News", adapter: "hacker_news", publication: "daily", sort_order: 1, config: { list: "top", count: 10, min_score: 0 } },
  { name: "GitHub Trending", adapter: "github_trending", publication: "daily", sort_order: 2, config: { languages: [], count: 10 } },
  { name: "Hackaday", adapter: "rss", publication: "daily", sort_order: 3, config: { feed_url: "https://hackaday.com/feed/", count: 10, window_hours: 24 } },
  { name: "阮一峰科技爱好者周刊", adapter: "ruanyf_weekly", publication: "weekly", sort_order: 1, config: { min_items: 5 } }
].each { |attrs| Source.find_or_create_by!(name: attrs[:name]) { |s| s.assign_attributes(attrs) } }
