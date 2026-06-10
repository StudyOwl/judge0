class AddExecutionIndexesToSubmissions < ActiveRecord::Migration[6.1]
  def change
    add_index :submissions, :status_id
    add_index :submissions, [:status_id, :created_at]
  end
end
