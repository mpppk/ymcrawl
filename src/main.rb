require_relative 'crawler'
require 'json'

json = []
open("site.json"){ |io| json = JSON.load(io) }
crawler = Crawler.new("./img", json["naver"])
crawler.save_images("http://matome.naver.jp/odai/2140544391008706001")
