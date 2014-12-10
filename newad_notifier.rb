require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'net/smtp'
require 'yaml'

database = YAML.load_file('config/database.yml')
email = YAML.load_file('config/email.yml')
lists = YAML.load_file('config/lists.yml')

url = lists['query_url']
db_file = database['file_name']

doc = Nokogiri::HTML(open(url))
items = doc.xpath(lists['xpath_expr'])

if items.length.zero?
	puts "Unsupported URL: #{url}"
else
	begin
		db = SQLite3::Database.open db_file
		db.execute "CREATE TABLE IF NOT EXISTS ads (
			id INTEGER PRIMARY KEY,
			title TEXT,
			created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
		)"
		new_items = []
		items.each { |ad_node|
			list_id = ad_node.attr('name').strip
			subject = ad_node.attr('title').strip
			db.execute(
				"INSERT INTO ads(id, title) SELECT ?, ?	WHERE NOT EXISTS(SELECT 1 FROM ads WHERE id = ?)",
				[list_id, subject, list_id]
			)
			if db.changes > 0
				ad_url = lists['ad_url'] % {:list_id => list_id}
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
			message = File.read(email['template_email']) % {
				:current_datetime => current_datetime,
				:sender_email => email['sender_email'],
				:recipient_name => email['recipient_name'],
				:recipient_email => email['recipient_email'],
				:number_of_ads => new_items.length,
				:new_items_string => new_items_string,
				:query_url => lists['query_url']
			}

			Net::SMTP.start('localhost') do |smtp|
				smtp.send_message message, email['sender_email'], email['recipient_email']
			end

			puts "#{new_items.length} new ads"

		end
	rescue SQLite3::Exception => e
		puts "Database exception occurred: #{e}"
	ensure
		db.close if db
	end
end
