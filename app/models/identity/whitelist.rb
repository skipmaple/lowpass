module Identity
  # R-5.5 管理员白名单：只从环境读（ADMIN_EMAILS，逗号分隔），比较时忽略大小写与空白；没配就没人是 admin
  module Whitelist
    def self.emails
      ENV["ADMIN_EMAILS"].to_s.split(",").map { |email| email.strip.downcase }.reject(&:empty?)
    end

    def self.include_any?(candidates)
      list = emails
      candidates.compact.any? { |email| list.include?(email.strip.downcase) }
    end
  end
end
