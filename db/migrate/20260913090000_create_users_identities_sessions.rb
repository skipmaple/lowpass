# PRD 附录 A 的 User / AuthIdentity / Session（设计第 3 节）。users.email 只做显示，是否已验证记在身份表；
# 未验证的邮箱不参与合并，所以 users.email 不唯一。
class CreateUsersIdentitiesSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: { type: :string, limit: 25 } do |t|
      t.string :display_name, limit: 100, null: false
      t.string :email, limit: 254
      t.string :avatar_url, limit: 2048
      t.string :role, limit: 10, null: false, default: "member"
      t.datetime :last_login_at
      t.timestamps

      t.check_constraint "role IN ('admin', 'member')", name: "users_role"
      t.check_constraint "length(display_name) <= 100", name: "users_display_name_len"
      t.check_constraint "length(email) <= 254", name: "users_email_len"
      t.check_constraint "length(avatar_url) <= 2048", name: "users_avatar_url_len"
    end

    create_table :auth_identities, id: { type: :string, limit: 25 } do |t|
      t.string :user_id, limit: 25, null: false
      t.string :provider, limit: 20, null: false
      t.string :provider_uid, limit: 255, null: false
      t.string :email, limit: 254
      t.boolean :email_verified, null: false, default: false
      t.datetime :linked_at, null: false
      t.timestamps

      t.index [ :provider, :provider_uid ], unique: true
      t.index :email
      t.index :user_id
      # developer 只在 development 产生（设计 L8），但约束里必须列上，否则那条路走不通
      t.check_constraint "provider IN ('google', 'github', 'developer')", name: "auth_identities_provider"
      t.check_constraint "length(provider_uid) <= 255", name: "auth_identities_provider_uid_len"
      t.check_constraint "length(email) <= 254", name: "auth_identities_email_len"
    end

    create_table :sessions, id: { type: :string, limit: 25 } do |t|
      t.string :user_id, limit: 25, null: false
      t.string :token, limit: 24, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :expires_at, null: false
      t.timestamps

      t.index :token, unique: true
      t.index :user_id
      t.check_constraint "length(token) <= 24", name: "sessions_token_len"
    end

    add_foreign_key :auth_identities, :users, on_delete: :cascade
    add_foreign_key :sessions, :users, on_delete: :cascade
  end
end
