ActiveRecord::Schema.define(version: 2021_04_29_143800) do
  create_table "addresses", force: :cascade do |t|
    t.string "state"
    t.string "country"
  end
end