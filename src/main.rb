require_relative 'naver-crawler'

crawler = NaverCrawler.new("./img")
crawler.get_images("http://matome.naver.jp/odai/2140544391008706001")
