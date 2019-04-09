require 'pry'
require 'watir'
require 'nokogiri'
require 'json'
require 'date'
require 'time'
require_relative 'accounts.rb'
require_relative 'transactions.rb'
require_relative 'estimate.rb'

class VB_WebBanking

  BASE_URL         = "https://web.vb24.md/wb/".freeze
  ACCOUNTS_URL     = "#{BASE_URL}#menu/MAIN_215.NEW_CARDS_ACCOUNTS".freeze
  TRANSACTIONS_URL = "#{BASE_URL}#menu/MAIN_215.CP_HISTORY".freeze
  DATA_DIR         = "data".freeze
  FILE_NAME        = "data/accounts.json".freeze

  attr_reader :accounts

  def run
    browser.goto(BASE_URL)
    browser.text_field(name: "login").present?
    authentication
    check_accounts
    check_transactions
  end

  def store
    Dir.mkdir(DATA_DIR) unless File.exists?(DATA_DIR)
    File.open(FILE_NAME, 'w') { |file| file.write(JSON.pretty_generate(assemble)) }
    puts "Accounts saved to #{FILE_NAME}"
  end

  private
  
  def browser
    @browser ||= Watir::Browser.new :chrome
  end

  def authentication
    if File.exist?('data/login.json')
      local_login
    else
      manual_login
    end

    browser.button(class: "wb-button").click
    sleep 2
    if browser.div(class: "block__cards-accounts").exist?
      puts "Authentication successful"
    else
      puts "Authentication failed, try again"
      authentication
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
    puts "Fetching account information"

    @accounts = []
    accounts_html.css('div.contracts-section').map do |page|
      unless page.css('div.section-title.no-data-error').any?
        name     = page.css('div.main-info').css('a.name').text
        balance  = page.css('div.primary-balance').css('span.amount').first.text.delete(',').estimate
        currency = page.css('div.primary-balance').css('span.amount.currency').text
        nature   = page.css('div.section-title.h-small').text.downcase.capitalize
        account  = Accounts.new(name, balance, currency, nature)
        @accounts << account
      end
    end
  end

  def check_transactions
    browser.goto(TRANSACTIONS_URL)
    puts "Fetching transactions for the last two months"

    @accounts.each do |account|
      browser.div(class: "chosen-container").click
      browser.div(class: "chosen-drop").span(text: account.name).click
      sleep 2
      set_date
      sleep 2 
      transactions_html.css('li.history-item.success').each do |page|
        year        = page.xpath('../../preceding-sibling::div[@class = "month-delimiter"]').last.text.split[1]
        month_name  = page.xpath('../../preceding-sibling::div[@class = "month-delimiter"]').last.text.split[0]
        month       = Date::MONTHNAMES.index(month_name).to_s
        day         = page.parent.parent.css('div.day-header').text.split[0]
        time        = page.css('span.history-item-time').text
        date        = Time.parse(year + "-" + month + "-" + day + " " + time)
        description = page.css('span.history-item-description').text.split.join(" ")
        if !page.css('span.history-item-amount.total').text.empty?
          amount    = page.css('span.history-item-amount.total').css('span[class="amount"]').text.estimate
          currency  = page.css('span.history-item-amount.total').css('span.amount.currency').text
        elsif !page.css('span.history-item-amount.transaction.income').text.empty?
          amount    = page.css('span.history-item-amount.transaction.income').css('span[class="amount"]').text.estimate
          currency  = page.css('span.history-item-amount.transaction.income').css('span.amount.currency').text
        else
          amount    = page.css('span.history-item-amount.transaction').css('span[class="amount"]').text.estimate
          currency  = page.css('span.history-item-amount.transaction').css('span.amount.currency').text
        end

        transaction = Transactions.new(date, description, amount, currency)
        account.transactions << transaction
      end
    end
  end

  def set_date
    day = Date.today.prev_month(2).day.to_s

    browser.input(name: 'from').click
    browser.a(class: %w"ui-datepicker-prev ui-corner-all").click
    browser.a(text: day).click
  end

  def assemble
    hash = {}
    hash["accounts"] = []

    @accounts.map do |account|
      account_hash = {
        'name'         => account.name,
        'balance'      => account.balance,
        'currency'     => account.currency,
        'nature'       => account.nature,
        'transactions' => []
      }
      
      account.transactions.map do |transaction|
        transaction_hash = {
          'date'        => transaction.date,
          'description' => transaction.description,
          'amount'      => transaction.amount,
          'currency'    => transaction.currency
        }
        
        account_hash['transactions'] << (transaction_hash)
      end
      hash["accounts"] << account_hash
    end
    hash
  end
end

parser = VB_WebBanking.new
parser.run
parser.store
puts File.read('data/accounts.json')


