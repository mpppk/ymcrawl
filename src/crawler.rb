require 'open-uri'
require 'nokogiri'
require 'kconv'
require 'addressable/uri'

class Crawler
  def initialize(dir, site_data)
    @image_selector = site_data["css"]["image"]
    @dir = dir
  end
  
  # 与えられたcssセレクタから画像を抽出する
  def get_images(url)
    get_urls(url, :image).each{|url| save_image(url, "test")}
  end
  
  private
  # 日本語のURLを読み込める形に変換する
  def normalize_url(url)
    puts "---- URL is null in normalize_url!!!!!!!!!!!!! ----" if url == nil
    Addressable::URI.parse(url).normalize.to_s
  end

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
    puts "src: #{url}"
    # ready filepath
    filename = "#{title}#{File.extname(url)}"
    cnt = 0
    filePath = "#{@dir}/#{get_unique_name(filename)}"
    # fileName folder if not exist
    FileUtils.mkdir_p(@dir) unless FileTest.exist?(@dir)

    # write image adata
    begin
      open(filePath, 'wb') do |output|
        puts "dst: #{filePath}"
        open(normalize_url(url)) do |data|
          output.write(data.read)
        end
      end
    rescue # ファイルが存在しないなどの理由で例外が発生した場合は、生成した画像を削除
      puts "image not exist."
      File.delete filePath
    end
  end

  # セレクタの一番最後のタグが何かを返す。擬似クラスなどは取り除く
  def get_last_tag(selector)
    # 一番最後の要素だけを返す。(擬似クラスなどは省く)
    selector.split(/\s|\+|>/).last.split(/:|,|\[|\.|#/).first
  end

  # 画像へのURLを返す
  def get_image_url(node, tag)
    return node["href"] if tag == "a"
    return node["src"] if tag == "img"
    raise ArgumentError, "invalid argument in get_image_url"
  end

  # 画像のタイトルへのURLを返す
  def get_image_title_link_attr(tag)
    # 未実装
  end

  # 記事タイトルへのURLを返す
  def get_title_link_attr(tag)
    # 未実装
  end

  # 対象に応じてURLを返す
  def get_url(node, tag, target)
    return get_image_url(node, tag) if target == :image
    return get_image_title_url(node, tag) if target == :image_title
    return get_title_url(node, tag) if target == :title
  end

  # 与えられたURLから、セレクタに従って画像のURLを返す
  def get_urls(url, target, nest = 0)
    css = @image_selector[nest]
    urls = []
    get_doc(url).css(css).each{ |node| urls << get_url(node, get_last_tag(css), target) }
    return urls if nest >= (@image_selector.length - 1)
    child_urls = []
    # 得られたURLそれぞれに対して次のセレクタを実行する
    urls.each{ |url| child_urls << get_urls(url, target, nest + 1) }
    child_urls.flatten
  end
end
