# 推荐理由（PRD 5.9）：接入层、解析、生成、账本都在这个命名空间下
module Reasons
  MISSING_AFTER = 30.minutes   # 5.7「某期发布 30 分钟后仍有条目无理由」

  # 生成的前提：供应商配好了，且画像里至少有一个启用的领域。画像空着提示词里没有领域名，
  # 每条都会判「缺领域名」重试满三次——照样调、照样记费用。现有的生产库里画像就是空的
  # （`db:prepare` 只给新建的库播种），这道门挡的是首次发布那一次白花钱
  def self.ready? = Reasons::Provider.configured? && InterestArea.enabled.exists?

  # 没准备好时告诉管理员缺的是哪一样（附录 B「推荐理由状态」「重生成理由」）
  def self.unready_label = Reasons::Provider.configured? ? "兴趣画像为空" : "未配置模型供应商"
end
