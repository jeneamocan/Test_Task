class Transactions
  attr_accessor :date, :description, :amount, :currency

  def initialize(date, description, amount, currency)
    @date        = date
    @description = description
    @amount      = amount
    @currency    = currency
  end
end
