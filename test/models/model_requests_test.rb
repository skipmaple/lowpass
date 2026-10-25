require "test_helper"

class ModelRequestsTest < ActiveSupport::TestCase
  test "同一个操作最多三次失败，重放不追加模型请求" do
    operation = ModelRequests.operation
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "太短", interest_tag: "AI / LLM"))
      2.times { assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one), operation: operation) }
      assert_requested stub, times: 3
      assert_equal 3, ModelCall.where(purpose: "reason", operation_key: operation.fetch("key")).count
    end
  end

  test "成功调用的重放不追加请求，七天到期操作也不请求" do
    operation = ModelRequests.operation
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: abstained_reply)
      2.times { assert_equal :abstained, Reasons::Generator.generate_item!(items(:hn_one), operation: operation) }
      assert_requested stub, times: 1
      expired = ModelRequests.operation(issued_at: 7.days.ago - 1.second)
      assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one), operation: expired)
      assert_equal "expired", Reasons::Generator.generate!(issues(:daily_0908), operation: expired).stop_reason
      assert_requested stub, times: 1
    end
  end

  test "限流和预算终止在同操作重放时仍然生效" do
    with_model_provider do
      operation = ModelRequests.operation
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 429)
      assert_raises(Reasons::Provider::Limited) { Reasons::Generator.generate_item!(items(:hn_one), operation: operation) }
      assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one), operation: operation)
      assert_requested stub, times: 1

      operation = ModelRequests.operation
      Setting.set("model_monthly_cap", "0.0001")
      ModelCall.create!(status: "ok", cost: "1")
      assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one), operation: operation)
      Setting.set("model_monthly_cap", "0")
      assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one), operation: operation)
      assert_requested stub, times: 1
    end
  end

  test "跨连接忙门不运行请求，异常后释放门" do
    # Rails事务fixture会把多个线程固定在同一session；另建PG连接才是真实跨连接竞争。
    config = ApplicationRecord.connection_db_config.configuration_hash
    other = PG.connect(host: config[:host], port: config[:port], dbname: config[:database], user: config[:username], password: config[:password], gssencmode: "disable")
    lock = "#{ModelRequests::LOCK_NAMESPACE}, #{ModelRequests::LOCK_KEY}"
    other.exec("SELECT pg_advisory_lock(#{lock})")
    assert_raises(ModelRequests::Busy) { ModelRequests.synchronize { flunk "不应进入已有请求门" } }
    other.exec("SELECT pg_advisory_unlock(#{lock})")
    assert_raises(RuntimeError) { ModelRequests.synchronize { raise "business failure" } }
    assert_equal "t", other.exec("SELECT pg_try_advisory_lock(#{lock})").getvalue(0, 0)
  ensure
    if other
      other.exec("SELECT pg_advisory_unlock_all()")
      other.close
    end
  end

  test "请求途中改单价只影响后续调用" do
    with_model_provider do
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do
        Setting.set("model_input_price", "100")
        Setting.set("model_output_price", "100")
        { status: 200, body: abstained_reply }
      end
      assert_equal :abstained, Reasons::Generator.generate_item!(items(:hn_one))
      assert_equal BigDecimal("0.0005"), ModelCall.last.cost
    end
  end

  test "请求门内预算读取不复用其他连接写入前的查询缓存" do
    config = ApplicationRecord.connection_db_config.configuration_hash
    other = PG.connect(host: config[:host], port: config[:port], dbname: config[:database], user: config[:username], password: config[:password], gssencmode: "disable")
    call_id = Lowpass::Uuid.generate
    Setting.set("model_monthly_cap", "1")
    ApplicationRecord.cache do
      ModelRequests.synchronize { assert_not Reasons::Budget.exhausted? }
      other.exec_params("INSERT INTO model_calls (id,status,cost,created_at) VALUES ($1,'ok',2,now())", [ call_id ])
      ModelRequests.synchronize { assert Reasons::Budget.exhausted? }
    end
  ensure
    if other
      other.exec_params("DELETE FROM model_calls WHERE id=$1", [ call_id ]) if call_id
      other.close
    end
  end

  test "最后一个合法结果耗尽预算也冻结本操作而不制造理由缺失事件" do
    operation = ModelRequests.operation
    with_model_provider do
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      Setting.set("model_monthly_cap", "0.0005")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: abstained_reply)
      assert_equal "budget", Reasons::Generator.generate!(issues(:daily_0908), operation: operation).stop_reason
      assert_equal 0, AlertEvent.where(kind: "reasons_missing").count
      Setting.set("model_monthly_cap", "0")
      assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one), operation: operation)
      assert_requested stub, times: 1
    end
  end

  test "预算停机和拒绝限流具有外层可识别停止原因" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 429)
      assert_equal "limited", Reasons::Generator.generate!(issues(:daily_0908)).stop_reason
      WebMock.reset!
      Setting.set("model_monthly_cap", "0.0001")
      ModelCall.create!(status: "ok", cost: "0.01")
      assert_equal "budget", Reasons::Generator.generate!(issues(:daily_0908)).stop_reason
    end
  end
end
