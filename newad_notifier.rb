#!/usr/bin/env ruby

require 'rake'
require 'yaml'
require 'open-uri'
require 'net/smtp'

require 'sqlite3'
require 'active_record'
require 'nokogiri'

# Establish the database connection
ActiveRecord::Base.establish_connection(
  YAML::load( File.open('config/database.yml') )['production']
)

# Invoke the rake db:migrate
Rake.application.init
Rake.application.load_rakefile
Rake::Task['db:migrate'].invoke

# Temp...
class Ad < ActiveRecord::Base; end

conf = YAML.load_file('conf.yml')

url = conf['query_url']
db_file = conf['db_file']

doc = Nokogiri::HTML(open(url))
items = doc.xpath(conf['xpath_expr'])

if items.length.zero?
	puts "Unsupported URL: #{url}"
else
	begin
		new_items = []
		items.each { |ad_node|
			list_id = ad_node.attr('name').strip
			subject = ad_node.attr('title').strip
			Ad.create :id => list_id, :title => subject
			if db.changes > 0
				ad_url = conf['ad_url'] % {:list_id => list_id}
				new_items.push({
					:list_id => list_id,
					:subject => subject,
					:url => ad_url
				})
			end
		}
		if new_items.length.zero?
			puts "No new ads"
		else
			new_items_string = new_items.map { |item| "#{item[:subject]} - #{item[:url]}" }.join("\n")
			current_datetime = Time.now.strftime "%d/%m/%Y %H:%M"
			message = File.read(conf['template_email']) % {
				:current_datetime => current_datetime,
				:sender_email => conf['sender_email'],
				:recipient_name => conf['recipient_name'],
				:recipient_email => conf['recipient_email'],
				:number_of_ads => new_items.length,
				:new_items_string => new_items_string,
				:query_url => conf['query_url']
			}

			Net::SMTP.start('localhost') do |smtp|
				smtp.send_message message, conf['sender_email'], conf['recipient_email']
			end

			puts "#{new_items.length} new ads"

		end
	rescue SQLite3::Exception => e
		puts "Database exception occurred: #{e}"
	ensure
		db.close if db
	end
end
