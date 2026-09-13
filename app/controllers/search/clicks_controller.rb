# 结果点击埋点（9.1 search_click）：前端 fetch(keepalive) 打一枪就走，返回 204。不是跳转端点，没有开放
# 跳转的口子。同样按 IP 限流：这个端点谁都能 POST，不限就是一张任人写的表。
class Search::ClicksController < ApplicationController
  rate_limit to: 60, within: 1.minute, by: -> { request.remote_ip }, with: -> { head :too_many_requests }

  def create
    Search::Click.record(item_id: params[:item_id].to_s, rank: rank, query: params[:q].to_s[0, 100])
    head :no_content
  end

  private
    def rank
      Integer(params[:rank].to_s, 10, exception: false)&.clamp(1, 1000) || 1
    end
end
