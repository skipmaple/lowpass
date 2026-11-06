class AddCurrencyAndTokenPricesToModelCalls < ActiveRecord::Migration[8.1]
  def change
    add_column :model_calls, :request_made, :boolean, null: false, default: true
    add_column :model_calls, :currency, :string, limit: 3
    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE model_calls SET currency = settings.value
          FROM settings WHERE settings.key = 'model_currency' AND settings.value IN ('USD', 'CNY')
        SQL
      end
    end
    add_column :model_calls, :cached_tokens, :integer, null: false, default: 0
    add_column :model_calls, :cache_write_tokens, :integer, null: false, default: 0
    %i[ input_price output_price cached_input_price cache_write_price ].each do |column|
      add_column :model_calls, column, :decimal, precision: 14, scale: 8
    end
    reversible do |direction|
      direction.up { change_column :model_calls, :cost, :decimal, precision: 16, scale: 8, null: false, default: 0 }
      direction.down { change_column :model_calls, :cost, :decimal, precision: 10, scale: 4, null: false, default: 0 }
    end
    add_check_constraint :model_calls, "currency IN ('USD', 'CNY')", name: "model_calls_currency_allowed"
    add_check_constraint :model_calls, "cached_tokens >= 0 AND cache_write_tokens >= 0 AND cached_tokens + cache_write_tokens <= prompt_tokens", name: "model_calls_cache_tokens_valid"
    remove_check_constraint :model_calls, "fallback_reason IN ('proxy_connect_failed')", name: "model_calls_fallback_reason_allowed"
    add_check_constraint :model_calls, "fallback_reason IN ('proxy_connect_failed', 'openai_quota_exhausted')", name: "model_calls_fallback_reason_allowed"
  end
end
