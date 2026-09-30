# 取消后的恢复（R-10.7）。取消是真删：服务端不留「已取消」的行（7.8 收藏到用户取消为止）。
# 删之前交给前端一张签过名的凭据，里面是这条收藏的全部字段；读者点「恢复」时凭它把同一条原样插回去，
# id 与收藏时间都不变。凭据一天后失效，只认签发给的那个人。
module Favorite::Undoing
  extend ActiveSupport::Concern

  UNDO_TTL = 1.day
  UNDO_COLUMNS = %w[ id url_hash url title title_zh summary summary_zh source_id publication period_key section anchor ].freeze

  class_methods do
    # 凭据无效、过期、不是这个人的，返回 nil。同一链接这期间又被收藏过，返回现有那条
    def restore(user, token)
      payload = undo_verifier.verified(token.to_s, purpose: :undo)

      if payload && payload["user_id"] == user.id
        attributes = payload.slice(*UNDO_COLUMNS).merge("created_at" => Time.iso8601(payload["created_at"]))
        user.favorites.create_with(attributes).find_or_create_by!(url_hash: payload["url_hash"])
      end
    end

    def undo_verifier = Rails.application.message_verifier("favorites/undo")
  end

  def undo_token
    payload = attributes.slice(*UNDO_COLUMNS).merge("user_id" => user_id, "created_at" => created_at.utc.iso8601(6))
    self.class.undo_verifier.generate(payload, expires_in: UNDO_TTL, purpose: :undo)
  end
end
