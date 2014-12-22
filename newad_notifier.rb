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

# Laading configuration files
database  = YAML.load_file('config/database.yml')
providers = YAML.load_file('config/providers.yml')
lists     = YAML.load_file('config/lists.yml')
email     = YAML.load_file('config/email.yml')

# Configuring the database connection
begin
	db = SQLite3::Database.open database['file_name']
rescue SQLite3::Exception => e
	puts "Database exception occurred: #{e}"
ensure
	exit if !db
end

# Checking the lists
new_items = []
lists.each do |list|

	# Getting list properties
	list_provider = list['provider']
	list_url = list['url']
	list_title = "(#{providers[list_provider]['title']}) #{list['title']}"
	ad_xpath = providers[list_provider]['ad_xpath']
	ad_url_pattern = providers[list_provider]['ad_url_pattern']

	# Getting list items from the provider
	doc = Nokogiri::HTML(open(list_url))
	items = doc.xpath(ad_xpath)

	# Processing the ads found
	if items.length.zero?
		puts "Unsupported URL: #{list_url}"
	else

		# Creating container for the current list
		new_list = new_items.push({
			:title => list_title,
			:url => list_url,
			:items => []
		}).last

		# Check each ad found
		items.each { |ad_node|

			# Getting ad properties
			ad_id = ad_node.attr('name').strip #TODO: Configure it on yaml file
			ad_title = ad_node.attr('title').strip #TODO: Configure it on yaml file
			ad_url = ad_url_pattern % {:id => ad_id}

			# Registering the ad if it's new
			db.execute(
				"INSERT INTO ads(id, title) SELECT ?, ?	WHERE NOT EXISTS(SELECT 1 FROM ads WHERE id = ?)",
				[ad_id, ad_title, ad_id]
			)
			if db.changes > 0
				new_list[:items].push({
					:id => ad_id,
					:title => ad_title,
					:url => ad_url
				})
			end
		}
	end

end

new_items_count = new_items.map { |list| list[:items].length }.inject(:+)

# Sending an email if any ad was found
if new_items_count.zero?
	puts "No new ads"
else
	new_items_string = new_items.map { |list|
		list_items_string = list[:items].map { |item| "- #{item[:title]} - #{item[:url]}" }.join("\n")
		"#{list[:title]}\n#{list[:url]}\n\n#{list_items_string}\n"
	}.join("\n")
	current_datetime = Time.now.strftime "%d/%m/%Y %H:%M"
	message = File.read(email['template_email']) % {
		:current_datetime => current_datetime,
		:sender_email => email['sender_email'],
		:recipient_name => email['recipient_name'],
		:recipient_email => email['recipient_email'],
		:number_of_ads => new_items_count,
		:new_items_string => new_items_string
	}

	Net::SMTP.start('localhost') do |smtp|
		smtp.send_message message, email['sender_email'], email['recipient_email']
	end

	puts "#{new_items_count} new ads"
end

# Closing the database
db.close if db
