# R-3.3 测试抓取：JSON 端点，表单不离开；每次最长 30 秒，所以每用户每分钟 10 次（设计 A12）
class Admin::Sources::TestFetchesController < Admin::BaseController
  rate_limit to: 10, within: 1.minute, by: -> { Current.user.id }, with: -> { head :too_many_requests }

  def create
    render json: Source::TestFetch.call(test_params).to_h
  end

  private
    def test_params
      params.permit(:id, :name, :adapter, :publication, config: {}).to_h
    end
end
