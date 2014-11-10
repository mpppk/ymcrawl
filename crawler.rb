require 'open-uri'
require 'nokogiri'
require 'kconv'
require 'addressable/uri'

class Crawler
  def initialize(selector, dir)
    @selector = selector
    @dir = dir
  end

  # 日本語のURLを読み込める形に変換する
  def normalize_url(url) Addressable::URI.parse(url).normalize.to_s end

  # 与えられたURLをパースして返す
  def get_doc(url)
    html = open(normalize_url(url), "r:binary").read
    Nokogiri::HTML(html.toutf8, nil, 'utf-8')
  end

  # ファイル名が既にimgディレクトリに存在していた場合はインデックスを付与する
  def get_unique_name(org_name)
    basename = (org_name == nil) ? "noname" : File.basename(org_name, '.*')
    ext = File.extname(org_name)
    return "#{basename}#{ext}" unless FileTest.exist?("#{@dir}/#{basename}#{ext}")
    index = 1
    retname = "#{basename}#{index}#{ext}"
    while FileTest.exist?("#{@dir}/#{retname}") do
      index = index + 1
      retname = "#{basename}#{index}#{ext}"
    end
    return retname
  end

  # 指定されたリンク先の画像を保存する
  def save_image(url, title)
    # ready filepath
    filename = "#{title}#{File.extname(url)}"
    cnt = 0
    filePath = "#{@dir}/#{get_unique_name(filename)}"
    # fileName folder if not exist
    FileUtils.mkdir_p(@dir) unless FileTest.exist?(@dir)

    # write image adata
    open(filePath, 'wb') do |output|
      open(normalize_url(url)) do |data|
        puts filePath
        output.write(data.read)
      end
    end
  end
end

# Naverまとめから画像をスクレイピングする
class NaverCrawler < Crawler
  def initialize(dir) super(".mdMTMWidget01ItemImg01 a:first-child", dir) end

  def get_title(node) node.css("img")[0]["title"] end

  # 指定したURLから画像を取得して保存する
  def get_images(url)
    doc = get_doc(url)
    doc.css(@selector).each do |node|
      get_doc(node["href"]).css(".mdMTMEnd01Img01 a:first-child").each do |node2|
        save_image(node2["href"], get_title(node))
      end
    end
  end
end

crawler = NaverCrawler.new("./img")
crawler.get_images("http://matome.naver.jp/odai/2140544391008706001")
