require "test_helper"

class InterestAreaTest < ActiveSupport::TestCase
  test "名称必填、最多 20 字、不区分大小写唯一；关键词最多 200 字" do
    area = InterestArea.new(name: "", keywords: "x")
    assert_not area.valid?
    assert_equal [ "必填" ], area.errors[:name]

    area.name = "a" * 21
    assert_not area.valid?
    assert_equal [ "最多 20 字" ], area.errors[:name]

    area.name = "ai / llm"
    assert_not area.valid?
    assert_equal [ "名称已存在" ], area.errors[:name]

    area.name = "新领域"
    area.keywords = "k" * 201
    assert_not area.valid?
    assert_equal [ "最多 200 字" ], area.errors[:keywords]
  end

  test "画像全文只含启用的领域，按排序" do
    assert_equal "AI / LLM：本地模型部署、Agent 框架、语音 AI、ASR/TTS、RAG\n前端开发：React、Web 技术、浏览器 API", InterestArea.profile_text
    assert_equal [ "AI / LLM", "前端开发" ], InterestArea.enabled_names
  end

  test "seed_defaults! 建满 10 个领域，重复执行不多写也不覆盖" do
    InterestArea.delete_all
    InterestArea.seed_defaults!
    assert_equal 10, InterestArea.count
    assert_equal "嵌入式开发", InterestArea.ordered.first.name

    InterestArea.find_by!(name: "AI / LLM").update!(keywords: "改过")
    InterestArea.seed_defaults!
    assert_equal 10, InterestArea.count
    assert_equal "改过", InterestArea.find_by!(name: "AI / LLM").keywords
  end
end
