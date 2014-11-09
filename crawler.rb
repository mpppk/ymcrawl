require 'open-uri'
require 'nokogiri'
require 'kconv'

DIR_NAME = "./img"
URL = "http://matome.naver.jp/odai/2140544391008706001?page=13"

# Naverまとめが何ページまであるかを返す
def get_max_page(url)

end

def get_unique_name(filename)
  index = 0
  filename = (filename == nil) ? "noname" : filename
	name = "#{filename}#{index}.jpg"
  while FileTest.exist?("#{DIR_NAME}/#{name}") do
  	index = index + 1
  end
	name = (index == 0) ? "#{filename}.jpg" : "#{filename}#{index}.jpg"
  return name
end

def save_image(url, title)
  # ready filepath
  fileName = File.basename(url)
  cnt = 0
  filePath = "#{DIR_NAME}/#{get_unique_name(title)}"
  puts filePath
  # fileName folder if not exist
  FileUtils.mkdir_p(DIR_NAME) unless FileTest.exist?(DIR_NAME)

  # write image adata
  open(filePath, 'wb') do |output|
    open(url) do |data|
      output.write(data.read)
    end
  end
end

SELECTOR = '.mdMTMWidget01Content01 img'
html = open(URL, "r:binary").read
doc = Nokogiri::HTML(html.toutf8, nil, 'utf-8')
# doc = Nokogiri::HTML(open(URL))
doc.css(SELECTOR).each do |node|
  save_image(node["src"], node["title"])
end

class NaverCrawler
  
end
