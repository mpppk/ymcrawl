require_relative 'crawler'
require 'json'

json = []
setting = JSON.parse( File.open("YMCrawlfile").read, {:symbolize_names => true} )
open(setting[:site_json]){ |io| json = JSON.load(io) }
crawler = Crawler.new(setting[:dst_dir], json["naver"], setting[:wait_time])
crawler.save_images(ARGV[0])
