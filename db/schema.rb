# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_04_29_013400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "leave_balances", force: :cascade do |t|
    t.decimal "accrued_hours"
    t.decimal "used_hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "leave_type_id", null: false
    t.index ["leave_type_id"], name: "index_leave_balances_on_leave_type_id"
    t.index ["user_id"], name: "index_leave_balances_on_user_id"
  end

  create_table "leave_requests", force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.decimal "requested_hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "leave_type_id", null: false
    t.index ["leave_type_id"], name: "index_leave_requests_on_leave_type_id"
    t.index ["user_id"], name: "index_leave_requests_on_user_id"
  end

  create_table "leave_types", force: :cascade do |t|
    t.string "name"
    t.decimal "accrual_rate"
    t.string "accrual_period"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_leave_types_on_user_id"
  end

  create_table "projected_requests", force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.decimal "requested_hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "leave_type_id", null: false
    t.index ["leave_type_id"], name: "index_projected_requests_on_leave_type_id"
    t.index ["user_id"], name: "index_projected_requests_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.date "start_date"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "leave_balances", "leave_types"
  add_foreign_key "leave_balances", "users"
  add_foreign_key "leave_requests", "leave_types"
  add_foreign_key "leave_requests", "users"
  add_foreign_key "leave_types", "users"
  add_foreign_key "projected_requests", "leave_types"
  add_foreign_key "projected_requests", "users"
end
