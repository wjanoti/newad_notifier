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
			message = <<MESSAGE_END
From: NewAd Notifier <tsmlima+newad-notifier@gmail.com>
To: Thiago Salles <tsmlima@gmail.com>
Subject: #{new_items.length} new ads! #{current_datetime}

There are #{new_items.length} new ads on the list you are watching:

#{new_items_string}

Link for the entire list: #{url}
MESSAGE_END

			Net::SMTP.start('localhost') do |smtp|
				smtp.send_message message, 'tsmlima+newad-notifier@gmail.com', 'tsmlima@gmail.com'
			end

			puts "#{new_items.length} new ads"
		end
	rescue SQLite3::Exception => e
		puts "Database exception occurred: #{e}"
	ensure
		db.close if db
	end
end
