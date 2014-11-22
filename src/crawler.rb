require 'open-uri'
require 'nokogiri'
require 'kconv'
require 'addressable/uri'
require 'singleton'

# URLに関する処理をまとめたクラス
class URLUtil
  def self.normalize_url(url)
    puts "---- URL is null in normalize_url!!!!!!!!!!!!! ----" if url == nil
    Addressable::URI.parse(url).normalize.to_s
  end
end

# CSSセレクタを表すクラス
class Selector
  def initialize(css)
    @selector = css
  end
  
  def to_s ;@selector end

  # セレクタの一番最後のタグが何かを返す。擬似クラスなどは取り除く
  def get_last_tag
    # 一番最後の要素だけを返す。(擬似クラスなどは省く)
    @selector.split(/\s|\+|>/).last.split(/:|,|\[|\.|#/).first
  end
end

# ホストごとの処理を管理するクラス
class HostManager
  include Singleton
  DEFAULT_WAIT_TIME = 2
  def initialize
    @host_list = {}
    @wait_time = DEFAULT_WAIT_TIME
  end

  def set_wait_time(wait_time) @wait_time = wait_time end

  # 最後にアクセスした日時を取得する
  def wait(url)
    host = URI( URLUtil.normalize_url(url) ).host
    unless @host_list[host] == nil then
      time_diff = Time.now - @host_list[host]
      puts "sleep: #{sleep(@wait_time - time_diff)}sec." if time_diff < @wait_time
    end
    @host_list[host] = Time.now
  end
end

# あるURLから取得できるHTMLドキュメントを抽象化したクラス
class Page
  class PageError < StandardError; end
  def initialize(url)
    @url = url
    @doc = get_doc
  end

  # 指定したcssセレクタに合致する要素を表すクラスの配列を返す
  def search_elements(selector) @doc.css(selector).map{ |doc| Element.new(doc) } end

  private
  # 与えられたURLをパースして返す
  def get_doc
    puts "get_doc from #{@url}"
    HostManager.instance.wait(@url)
    html = open(URLUtil.normalize_url(@url), "r:binary").read
    Nokogiri::HTML(html.toutf8, nil, 'utf-8')
  rescue OpenURI::HTTPError => ex
    puts "failed URL: #{@url}"
    puts "HTTP Error message: #{ex.message}"
    raise PageError.new(ex.message)
  end
end

# セレクタにより抽出されたPageの一部を表すクラス
class Element
  def initialize(doc) @doc = doc end

  def get_url; @doc["href"] end

  # 画像へのURLを返す
  def get_image_url
    return @doc["href"] if @doc.name == "a"
    return @doc["src"]  if @doc.name == "img"
    raise ArgumentError, "in Element"
  end

  # 画像のタイトルを返す
  def get_image_title
    title = (@doc.name == "img") ? @doc["title"] : @doc.content
    (title == nil) ? "noname" : title
  end

  # 記事タイトルを返す
  def get_title; @doc.content end

  # 記事が何ページまであるかを返す
  def get_page_index_max; @doc.content.to_i end

  # 対象に応じてURLを返す
  def get_content(target)
    return get_url            if target == :url
    return get_image_url      if target == :image
    return get_image_title    if target == :image_title
    return get_title          if target == :title
    return get_page_index_max if target == :page_index_max
  end
end

# 画像のスクレイピングを行うクラス
class Crawler
  INDEX_STR = "{index}" # jsonファイルでINDEX番号が入る場所を表す文字列

  def initialize(dir, site_data, wait_time)
    HostManager.instance.set_wait_time(wait_time)
    @selectors = {}
    @selectors[:image]          = site_data["css"]["image"].map          { |s| Selector.new(s) }
    @selectors[:image_title]    = site_data["css"]["image_title"].map    { |s| Selector.new(s) }
    @selectors[:title]          = site_data["css"]["title"].map          { |s| Selector.new(s) }
    @selectors[:page_index_max] = site_data["css"]["page_index_max"].map { |s| Selector.new(s) }
    @page_index_min             = site_data["page_index_min"]
    @next_page_appendix         = site_data["next_page_appendix"]
    @dir = dir
  end
  
  # 与えられたcssセレクタから画像を抽出する
  def save_images(original_url)
    dst_dir = "#{@dir}/#{get_contents(original_url, :title).first}"
    (@page_index_min..get_page_index_max(original_url) ).each do |page_index|
      url = "#{original_url}#{get_next_page_appendix_with_index(page_index)}"
      get_contents(url, :image).zip(get_contents(url, :image_title)) do |url, title|
        save_image(dst_dir, url, title) unless url == nil
      end
    end
    dst_dir
  end
  
  private
  # ファイル名が既にimgディレクトリに存在していた場合はインデックスを付与する
  def get_unique_name(dir, org_name)
    basename = (org_name == nil) ? "noname" : File.basename(org_name, '.*')
    ext = File.extname(org_name)
    return "#{basename}#{ext}" unless FileTest.exist?("#{dir}/#{basename}#{ext}")
    index = 1
    retname = "#{basename}#{index}#{ext}"
    while FileTest.exist?("#{dir}/#{retname}") do
      index = index + 1
      retname = "#{basename}#{index}#{ext}"
    end
    return retname
  end

  # 指定されたリンク先の画像を保存する
  def save_image(dst_dir, url, title)
    puts "src: #{url}"
    # ready filepath
    filename = "#{title}#{File.extname(url)}"
    filePath = "#{dst_dir}/#{get_unique_name(dst_dir, filename)}"
    HostManager.instance.wait(url)
    # fileName folder if not exist
    FileUtils.mkdir_p(dst_dir) unless FileTest.exist?(dst_dir)
    # write image adata
    begin
      open(filePath, 'wb') do |output|
        puts "dst: #{filePath}"
        open(URLUtil.normalize_url(url)) do |data|
          output.write(data.read)
        end
      end
    rescue # ファイルが存在しないなどの理由で例外が発生した場合は、生成した画像を削除
      puts "image not exist."
      File.delete filePath
    end
  end

  def get_next_page_appendix_with_index(index) @next_page_appendix.gsub("{index}", index.to_s) end

  def get_page_index_max(url)
    page_index_max = get_contents(url, :page_index_max)
    return @page_index_min if page_index_max.length == 0
    (page_index_max.first.kind_of?(Integer)) ? page_index_max.first : @page_index_min
  end

  # 与えられたURLから、セレクタに従って画像のURLを返す
  def get_contents(url, target, nest = 0)
    selector = @selectors[target][nest]
    if nest >= (@selectors[target].length - 1)
      return Page.new(url).search_elements(selector.to_s).map{ |cn| cn.get_content(target) } 
    end
    # 得られたURLそれぞれに対して次のセレクタを実行する
    contents = Page.new(url).search_elements(selector.to_s).map{ |cn| cn.get_content(:url) } 
    contents.map{ |c| get_contents(c, target, nest + 1) }.flatten
  rescue Page::PageError => ex
    puts "error in get_contents #{ex}"
    return nil
  end
end
