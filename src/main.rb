require_relative 'crawler'
require 'json'

SITE_JSON_NAME = "site.json"
setting = JSON.parse( File.open("YMCrawlfile").read, {:symbolize_names => true} )
json_file_pass = FileTest.exist?(SITE_JSON_NAME) ? SITE_JSON_NAME : setting[:site_json]
puts "reading site json file from #{json_file_pass}"
json = JSON.parse( open(json_file_pass).read, {:symbolize_names => true} )
File.write( SITE_JSON_NAME, JSON.unparse(json) ) unless FileTest.exist?(SITE_JSON_NAME)
crawler = Crawler.new(setting[:dst_dir], json[:naver], setting[:wait_time])
ARGV.each{ |v| crawler.save_images(v) }
