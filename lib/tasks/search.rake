namespace :search do
  desc "清空并按 items 重建搜索索引（Search::Record.rebuild!）；迁移后跑一次，见 docs/development.md「搜索」"
  task rebuild: :environment do
    puts "search_records: #{Search::Record.rebuild!}"
  end
end
