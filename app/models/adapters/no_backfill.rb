module Adapters
  # 7.7：这个源不能回填历史日期。缺期补生成时该栏固化成 no_backfill，读者页写「该来源无法回填」
  NoBackfill = Class.new(StandardError)
end
