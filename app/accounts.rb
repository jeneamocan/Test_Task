class Accounts
  attr_accessor :name, :balance, :currency, :nature, :transactions

  def initialize(name, balance, currency, nature)
    @name         = name
    @balance      = balance
    @currency     = currency
    @nature       = nature
    @transactions = []
  end
end
