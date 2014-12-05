require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'net/smtp'
require 'yaml'

conf = YAML.load_file('conf.yml')

url = conf['query_url']
db_file = conf['db_file']

doc = Nokogiri::HTML(open(url))
items = doc.xpath(conf['xpath_expr'])

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
			file = File.open(conf['template_email'])
			message = file.read % {
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
