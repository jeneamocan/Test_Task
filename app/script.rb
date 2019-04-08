require 'pry'
require 'watir'
require 'nokogiri'
require 'json'
require 'date'

class VB_WebBanking
  BASE_URL = "https://web.vb24.md/wb/".freeze
  ACCOUNTS_URL = "#{BASE_URL}#menu/MAIN_215.NEW_CARDS_ACCOUNTS".freeze
  TRANSACTIONS_URL = "#{BASE_URL}#menu/MAIN_215.CP_HISTORY".freeze

  attr_reader :accounts, :transactions

  def run
    browser.goto(BASE_URL)
    sleep 2
    authentication_check
    check_accounts
    check_transactions
    add_transactions
    store
  end

  private
  
  def browser
    @browser ||= Watir::Browser.new :chrome
  end

  def authentication_check
    if browser.text_field(name: "login").present?
      puts "Authentication required"
      authentication
    end
  end

  def authentication
    unless File.exist?('data/login.json')
      manual_login
    else
      local_login
    end
    browser.button(class: "wb-button").click
    sleep 2
    if browser.div(class: "block__cards-accounts").exist?
      puts "Authentication successful"
    else
      puts "Authentication failed, try again"
      manual_login
    end
  end

  def local_login
    file = File.read('data/login.json')
    json = JSON.parse(file)
    browser.text_field(name: "login").set(json["login"])
    browser.text_field(name: "password").set(json["password"])
  end

  def manual_login
    puts "Enter your login"
    browser.text_field(name: "login").set(gets.chomp)
    puts "Enter your password"
    browser.text_field(name: "password").set(gets.chomp)
    if browser.text_field(name: "captcha").present?
      puts "Enter CAPTCHA"
      browser.text_field(name: "captcha").set(gets.chomp)
    end
  end

  def accounts_html
    Nokogiri::HTML.parse(browser.div(class: "contracts-section").html)
  end

  def transactions_html
    Nokogiri::HTML.parse(browser.div(class: "operations").html)
  end

  def check_accounts
    browser.goto(ACCOUNTS_URL)
    puts "Fetching account informatrion"
    @accounts = Array.new
    accounts_html.css('div.contracts-section').map do |page|
      unless page.css('div.section-title.no-data-error').any?
        name     = page.css('div.main-info').css('a.name').text
        balance  = page.css('div.primary-balance').css('span.amount').first.text
        currency = page.css('div.primary-balance').css('span.amount').last.text
        nature   = page.css('div.section-title.h-small').text.downcase.capitalize
        account  = Accounts.new(name, balance, currency, nature)
        @accounts << account
      end
    end
  end

  def check_transactions
    browser.goto(TRANSACTIONS_URL)
    set_date
    sleep 2 
    puts "Fetching transactions for the last two months"
    @transactions = Array.new
    transactions_html.css('li.history-item.success').map do |page|
      year  = page.xpath('../../preceding-sibling::div[@class = "month-delimiter"]').last.text.split[1]
      month = page.xpath('../../preceding-sibling::div[@class = "month-delimiter"]').last.text.split[0]
      day   = page.parent.parent.css('div.day-header').text.split[0]
      time  = page.css('span.history-item-time').text
      date  = (year + " " + month + " " + day).to_s
      description = page.css('span.history-item-description').text.split.join(" ")
      if !page.css('span.history-item-amount.transaction.income').text.empty?
        amount = page.css('span.history-item-amount.transaction.income').text
      elsif !page.css('span.history-item-amount.total').text.empty?
        amount = page.css('span.history-item-amount.total').text
      else
        amount = page.css('span.history-item-amount.transaction').text
      end
    transaction = Transactions.new(date, description, amount)
    @transactions << transaction
    end
  end

  def set_date
    day = Date.today.prev_month(2).day.to_s
    browser.input(name: 'from').click
    browser.a(class: %w"ui-datepicker-prev ui-corner-all").click
    browser.a(text: "#{day}").click
  end

  def add_transactions
    @accounts.each do |acount|
      @transactions.each do |transaction|
        acount.transactions << transaction
      end
    end
  end

  def assemble
    hash = Hash.new
    @accounts.map do |account|
      account_hash = Hash.new
      account_hash['name'] = account.name
      account_hash['balance'] = account.name
      account_hash['currency'] = account.currency
      account_hash['nature'] = account.nature
      account_hash['transactions'] = []
      account.transactions.map do |transaction|
        transaction_hash = Hash.new
        transaction_hash['date'] = transaction.date
        transaction_hash['description'] = transaction.description
        transaction_hash['amount'] = transaction.amount
        account_hash['transactions'].push(transaction_hash)
      end
    hash["accounts"] = account_hash
    hash
    end
  end

  def store
  Dir.mkdir('data') unless File.exists?('data')
  file_name = 'data/accounts.json'
  File.open(file_name, 'w') { |file| file.write(JSON.pretty_generate(assemble)) }
  puts "Accounts saved to #{file_name}"
  end
end

class Accounts
  attr_accessor :name, :balance, :currency, :nature, :transactions

  def initialize (name, currency, balance, nature)
    @name         = name
    @currency     = currency
    @balance      = balance
    @nature       = nature
    @transactions = Array.new
  end
end

class Transactions
  attr_accessor :date, :description, :amount

  def initialize (date, description, amount)
    @date        = date
    @description = description
    @amount      = amount
  end
end
  
parser = VB_WebBanking.new
parser.run
puts File.read('data/accounts.json')
