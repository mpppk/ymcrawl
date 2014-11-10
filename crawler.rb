require 'open-uri'
require 'nokogiri'
require 'kconv'

class Crawler
  def initialize(selector, dir)
    @selector = selector
    @dir = dir
  end
  # ファイル名が既にimgディレクトリに存在していた場合はインデックスを付与する
  def get_unique_name(filename)
    index = 0
    filename = (filename == nil) ? "noname" : filename
    name = "#{filename}#{index}.jpg"
    while FileTest.exist?("#{@dir}/#{name}") do
      index = index + 1
    end
    name = (index == 0) ? "#{filename}.jpg" : "#{filename}#{index}.jpg"
    return name
  end

  # 指定されたリンク先の画像を保存する
  def save_image(url, title)
    # ready filepath
    fileName = File.basename(url)
    cnt = 0
    filePath = "#{@dir}/#{get_unique_name(title)}"
    puts filePath
    # fileName folder if not exist
    FileUtils.mkdir_p(@dir) unless FileTest.exist?(@dir)

    # write image adata
    open(filePath, 'wb') do |output|
      open(url) do |data|
        output.write(data.read)
      end
    end
  end

  # 取得したURLから、オリジナルサイズの画像へのURLを取得する。オーバーライドすることを想定。
  def get_original_image_url(url)
    url
  end

  # 指定したURLから画像を取得して保存する
  def get_images(url)
    html = open(url, "r:binary").read
    doc = Nokogiri::HTML(html.toutf8, nil, 'utf-8')
    doc.css(@selector).each do |node|
      save_image(node["src"], node["title"])
    end
  end
end

class NaverCrawler < Crawler
  def initialize(dir)
    super(".mdMTMWidget01Content01 img", dir)
  end

  # 取得したURLから、オリジナルサイズの画像へのURLを取得する。オーバーライドすることを想定。
  def get_original_image_url(url)
    url
  end
end

# main
crawler = NaverCrawler.new("./img")
crawler.get_images("http://matome.naver.jp/odai/2140544391008706001")
