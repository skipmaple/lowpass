class AddAbstainedToModelCalls < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :model_calls, name: "model_calls_status"
    add_check_constraint :model_calls, "status IN ('ok', 'failed', 'timed_out', 'invalid', 'abstained')", name: "model_calls_status"
  end

  # 已产生的合法拒写账本不能由回退删除或改写；应用回退保留本次扩展。
  def down
    raise ActiveRecord::IrreversibleMigration, "保留 abstained 账本与状态约束；只回退应用前须停止理由任务"
  end
end
