require_relative 'naver-crawler'
require 'json'

json = []
open("site.json") do |io|
	json = JSON.load(io) #=> [1, 2, 3, {"foo"=>"bar"}]
end

crawler = Crawler.new("./img", json["naver"])
crawler.get_images("http://matome.naver.jp/odai/2140544391008706001")
