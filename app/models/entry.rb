class Entry < ApplicationRecord
  belongs_to :user
  belongs_to :category

  validates :date, :presence => true
  validates :amount, :presence => true
  validates :amount, :numericality => { :greater_than_or_equal_to => 0 }
  # validates :amount, numericality: { only_integer: true }
  validates :user_id, :presence => true
  validates :category_id, :presence => true
end
