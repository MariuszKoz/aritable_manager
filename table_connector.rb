#frozen_string_literal: true
require 'bundler/inline'
require 'httparty'
require 'pry'

gemfile do
  source 'https://rubygems.org'
  gem 'tty-prompt'
  gem 'terminal-table'
end

prompt = TTY::Prompt.new

# Connection with AirTable table
api_key = prompt.ask('first of all, api_key:')
base_id = prompt.ask('now I need table base_id:')
table_name = prompt.ask('and this table name:')

api_url = "https://api.airtable.com/v0/#{base_id}/#{table_name}"
headers = {
  'Authorization' => "Bearer #{api_key}",
  'Content-Type' => 'application/json'
}

@response = HTTParty.get(api_url, headers: headers)

if @response.code == 200
  puts "Table '#{table_name}' connected"
  puts "Your #{table_name} table contains #{@response["records"].count} records. Below you've got list of those records, with values of those three main columns"
else
  puts "Error: #{@response.code} - #{@response.body}"
end

# print table
headings = ['ID', 'IP', 'Status']
rows = []
@response["records"].each { |record| rows << headings.each.with_object([]) { |header, record_row| record_row << record["fields"][header] } }
table = Terminal::Table.new :title => table_name, :headings => headings, :rows => rows
puts table

# choose record
question = "Which do you interested in?"
options_for_select = []
@response["records"].each do |option|
  result_string = "ID => #{option["fields"]["ID"]}"
  options_for_select << result_string
end
chosen_record = prompt.select(question, options_for_select)

# print selected record
id_match = chosen_record.match(/ID\s*=>\s*([a-zA-Z0-9]+)/)[1]
selected_record = @response["records"].detect { | option| option["fields"]["ID"] == id_match.to_i }

puts "Here you've got chosen record crucial data:"

selected_record_table_name = "Servers record: #{selected_record["fields"]["IP"]}"
table = Terminal::Table.new :title => selected_record_table_name, :headings => selected_record["fields"].keys.first(9), :rows => [selected_record["fields"].values.first(9)]
puts table

# select argument to manage
question = "Here you've got record arguments, select which one you want to manage:"
options_for_select = selected_record["fields"].keys
chosen_argument = prompt.select(question, options_for_select)

# put value for argument
new_value = prompt.ask('Put new value for that argument:')

# confirm new value
question = "Do you want to change #{chosen_argument} value from: #{selected_record["fields"][chosen_argument]} to: #{new_value} ?"
confirm = prompt.select(question, %w[yes no])

# send update to Airtable
if confirm == "yes"
  value_to_update = selected_record["fields"][chosen_argument].is_a?(Integer) ? new_value.to_i : new_value
  @request = HTTParty.patch("https://api.airtable.com/v0/#{base_id}/#{table_name}/#{selected_record["id"]}", headers: headers, body: { fields: {chosen_argument => value_to_update}}.to_json)
end
