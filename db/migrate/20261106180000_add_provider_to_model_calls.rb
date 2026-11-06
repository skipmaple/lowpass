class AddProviderToModelCalls < ActiveRecord::Migration[8.1]
  def change
    add_column :model_calls, :provider_host, :string, limit: 253
    add_column :model_calls, :provider_model, :string, limit: 255
    add_column :model_calls, :fallback_reason, :string, limit: 32
    add_check_constraint :model_calls, "char_length(provider_host) <= 253", name: "model_calls_provider_host_length"
    add_check_constraint :model_calls, "char_length(provider_model) <= 255", name: "model_calls_provider_model_length"
    add_check_constraint :model_calls, "fallback_reason IN ('proxy_connect_failed')", name: "model_calls_fallback_reason_allowed"
  end
end
