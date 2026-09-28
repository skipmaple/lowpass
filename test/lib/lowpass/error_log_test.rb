require "test_helper"

# config/initializers/error_reporting.rb 给 Rails.error 挂的订阅者。Rails.error.report 自己一个字都不写，
# 没有订阅者，调度某一步、告警门面、搜索不可用这些 handled 的报告在生产上不留痕迹。
# 这里全走 Rails.error.report，挂没挂上一起测
class Lowpass::ErrorLogTest < ActiveSupport::TestCase
  # 订阅者每次报告时才取 Rails.logger，换掉它就能抓到那一行；默认格式不打级别，这里带上
  setup do
    @log = StringIO.new
    @original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(@log).tap { |logger| logger.formatter = ->(severity, _time, _progname, message) { "#{severity} #{message}\n" } }
  end

  teardown { Rails.logger = @original_logger }

  test "handled 的报告写一行：类名、消息首行、级别、来源与白名单里的上下文" do
    Rails.error.report(RuntimeError.new("第一行\n第二行"), handled: true, context: { step: :generate_daily_if_due })

    assert_equal [ %(WARN 错误上报：RuntimeError "第一行" severity=warning handled=true source=application step=generate_daily_if_due) ], logged_lines
  end

  test "日志级别跟着 severity 走" do
    Rails.error.report(RuntimeError.new("没接住"), handled: false)
    Rails.error.report(RuntimeError.new("只是提示"), handled: true, severity: :info)

    assert_equal %w[ ERROR INFO ], logged_lines.map { |line| line.split(" ", 2).first }
  end

  # D12：搜索日志不关联用户。Authentication 把 user_id 放进错误上下文，Search::Runner 报告时带着原始搜索词，
  # 两样写进同一行，日志里就能看出谁搜了什么
  test "搜索词和 user_id 不写进同一行（D12）" do
    user_id = users(:drew).id
    Rails.error.set_context(user_id: user_id)
    Rails.error.report(ActiveRecord::QueryCanceled.new("canceling statement due to statement timeout"), handled: true, context: { search: "kubernetes operator" })

    assert_equal 1, logged_lines.size
    assert_empty logged_lines.select { |line| line.include?("kubernetes operator") && line.include?(user_id) }
  end

  private
    def logged_lines = @log.string.lines(chomp: true)
end
