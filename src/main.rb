require_relative 'naver-crawler'
require 'json'

json = []
open("site.json"){ |io| json = JSON.load(io) }
crawler = Crawler.new("./img", json["naver"])
crawler.get_images("http://matome.naver.jp/odai/2140544391008706001")
