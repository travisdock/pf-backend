class Entry < ApplicationRecord
  require 'csv'
  belongs_to :user
  belongs_to :category

  validates :date, :presence => true
  validates :amount, :presence => true
  validates :amount, :numericality => { :greater_than_or_equal_to => 0 }
  # validates :amount, numericality: { only_integer: true }
  validates :user_id, :presence => true
  validates :category_id, :presence => true

  def self.currency_to_number(currency)
    currency.to_s.gsub(/[$,]/,'').to_f
  end

  def self.import(params)
    csv_text = File.read(params['file'].tempfile)
    @user = User.find(params['user_id'])
    csv = CSV.parse(csv_text, :headers => true, :encoding => 'ISO-8859-1')
    entries_to_save = []
    created_categories = []
    csv.each do |row|
      data = row.to_hash

      # Validate entry amount and convert to number
      begin
        data['Amount'] = Entry.currency_to_number(data['Amount'])
      rescue StandardError => msg
        raise "Error adding an entry (Date: #{data['Date']}, Category: #{data['Category']}, Amount: #{data['Amount']}, Notes: #{data['Notes']}) to the queue because of the following error:  #{msg.message}"
      end
      # Validate entry date and set year variable
      begin
        entry_year = DateTime.parse(data['Date']).year
      rescue StandardError => msg
        raise "Error adding an entry (Date: #{data['Date']}, Category: #{data['Category']}, Amount: #{data['Amount']}, Notes: #{data['Notes']}) to the queue because of the following error:  #{msg.message}"
      end
      
      category_with_date = @user.categories.where(year: entry_year).select{ |cat| cat.name == data['Category'] }[0]
      category_without_date = @user.categories.select{ |cat| cat.name == data['Category'] }[0]

      if category_with_date
        @category = category_with_date
      elsif category_without_date
        @category = category_without_date.dup
        @category.year = entry_year
        @category.save
        @user.categories << @category
      else
        @category = nil
      end

      if @category
        @entry = Entry.new(user_id: @user.id, amount: data['Amount'], date: data['Date'], notes: data['Notes'], category_id: @category.id, category_name: @category.name, income: @category.income, untracked: @category.untracked)
        if @entry.valid?
          entries_to_save.push(@entry)
        else
          if created_categories.length > 0
            created_categories.each do |cat|
              cat.destroy
            end
          end
          raise "Error adding an entry (Date: #{@entry.date}, Category: #{@entry.category.name}, Amount: #{@entry.amount}, Notes: #{@entry.notes}) to the queue because of the following error:  #{@entry.errors.full_messages}"
        end
      else
        @new_category = Category.new(name: data['Category'], income: false, untracked: false, year: entry_year)
        if @new_category.valid?
          @new_category.save
          @user.categories << @new_category
          created_categories << @new_category
          @entry = Entry.new(user_id: @user.id, amount: data['Amount'], date: data['Date'], notes: data['Notes'], category_id: @new_category.id, category_name: @new_category.name, income: @new_category.income, untracked: @new_category.untracked)
          if @entry.valid?
            entries_to_save.push(@entry)
          else
            if created_categories.length > 0
              created_categories.each do |cat|
                cat.destroy
              end
            end
            raise "Error adding an entry (Date: #{@entry.date}, Category: #{@entry.category.name}, Amount: #{@entry.amount}, Notes: #{@entry.notes}) to because of the following error:  #{@entry.errors.full_messages}"
          end
        else
          if created_categories.length > 0
            created_categories.each do |cat|
              cat.destroy
            end
          end
          raise "Error adding new category (Name: #{@new_category.name}) for an entry (amount: #{data['Amount']}, date: #{data['Date']}, notes: #{data['Notes']}) because of the following error: #{@new_category.errors.full_messages}"
        end
      end
    end

    entries_to_save.each do |entry|
      entry.save
    end
  end
end
