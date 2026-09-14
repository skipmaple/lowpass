# 兴趣画像（PRD 5.9、D18）：全局一份，管理员在后台维护；领域名就是条目的 interest_tag（7.2 限 20 字），
# 关键词原样进提示词。停用的领域不进提示词，已生成的标签不动（设计 C5）
class InterestArea < ApplicationRecord
  DEFAULTS = [
    [ "嵌入式开发", "ESP32、MCU、固件、RTOS" ],
    [ "AI / LLM", "本地模型部署、Agent 框架、语音 AI、ASR/TTS、RAG" ],
    [ "前端开发", "React、Web 技术、浏览器 API" ],
    [ "后端开发", "Ruby、Rails、Go、Python、服务端框架" ],
    [ "后端架构", "分布式系统、微服务、数据库、消息队列" ],
    [ "UI/UX", "设计工具、设计系统、交互设计、用户体验" ],
    [ "硬件设计", "电路、PCB、传感器、音频系统" ],
    [ "电子机械与自动化", "电机控制、PLC、机器人、自动化系统" ],
    [ "开发者效率", "CLI 工具、编辑器插件、CI/CD、Git 工作流" ],
    [ "智能家居 / IoT", "Home Assistant、MQTT、智能设备" ]
  ].freeze

  validates :name, presence: { message: "必填" }, length: { maximum: 20, message: "最多 20 字" },
                   uniqueness: { case_sensitive: false, message: "名称已存在" }
  validates :keywords, length: { maximum: 200, message: "最多 200 字" }

  scope :ordered, -> { order(:sort_order, :name) }
  scope :enabled, -> { where(enabled: true) }

  # 提示词里的画像全文：一行一个领域「名称：关键词」
  def self.profile_text = enabled.ordered.map { |area| "#{area.name}：#{area.keywords}" }.join("\n")
  def self.enabled_names = enabled.ordered.pluck(:name)

  # PRD 5.9 的初始画像：按名称找，有就不动（管理员改过的关键词不能被种子覆盖）
  def self.seed_defaults!
    DEFAULTS.each_with_index do |(name, keywords), index|
      find_or_create_by!(name: name) { |area| area.assign_attributes(keywords: keywords, sort_order: index + 1) }
    end
  end
end
