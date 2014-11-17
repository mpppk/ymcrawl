require 'open-uri'
require 'nokogiri'
require 'kconv'
require 'addressable/uri'

class HostManager
  def initialize(wait_time)
    @host_list = {}
    @wait_time = wait_time
  end

  # 最後にアクセスした日時を取得する
  def wait(url)
    host = URI( normalize_url(url) ).host
    unless @host_list[host] == nil then
      time_diff = Time.now - @host_list[host]
      puts "sleep: #{sleep(@wait_time - time_diff)}sec." if time_diff < @wait_time
    end
    @host_list[host] = Time.now
  end

  # 日本語のURLを読み込める形に変換する
  def normalize_url(url)
    puts "---- URL is null in normalize_url!!!!!!!!!!!!! ----" if url == nil
    Addressable::URI.parse(url).normalize.to_s
  end
end

class Crawler
  INDEX_STR = "{index}" # jsonファイルでINDEX番号が入る場所を表す文字列
  def initialize(dir, site_data, wait_time)
    @h_mng = HostManager.new(wait_time)
    @selector = {}
    @selector[:image] = site_data[:css][:image]
    @selector[:image_title] = site_data[:css][:image_title]
    @selector[:title] = site_data[:css][:title]
    @selector[:page_index_max] = site_data[:css][:page_index_max]
    @page_index_min = site_data[:page_index_min]
    @next_page_appendix = site_data[:next_page_appendix]
    @dir = dir
  end
  
  # 与えられたcssセレクタから画像を抽出する
  def save_images(original_url)
    dst_dir = "#{@dir}/#{get_contents(original_url, :title).first}"
    (@page_index_min..get_contents(original_url, :page_index_max).first ).each do |page_index|
      url = "#{original_url}#{get_next_page_appendix_with_index(page_index)}"
      get_contents(url, :image).zip(get_contents(url, :image_title)) do |url, title|
        save_image(dst_dir, url, title) unless url == nil
      end
    end
  end
  
  private
  # 日本語のURLを読み込める形に変換する
  def normalize_url(url)
    puts "---- URL is null in normalize_url!!!!!!!!!!!!! ----" if url == nil
    Addressable::URI.parse(url).normalize.to_s
  end

  # 与えられたURLをパースして返す
  def get_doc(url)
    puts "get_doc from #{url}"
    @h_mng.wait(url)
    html = open(normalize_url(url), "r:binary").read
    Nokogiri::HTML(html.toutf8, nil, 'utf-8')
  rescue => ex
    puts "failed URL: #{url}"
    throw ex
  end

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
    cnt = 0
    filePath = "#{dst_dir}/#{get_unique_name(dst_dir, filename)}"
    @h_mng.wait(url)
    # fileName folder if not exist
    FileUtils.mkdir_p(dst_dir) unless FileTest.exist?(dst_dir)
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

  # 画像のタイトルを返す
  def get_image_title(node, tag)
    title = (tag == "img") ? node["title"] : node.content
    (title == nil) ? "noname" : title
  end

  # 記事タイトルを返す
  def get_title(node, tag) node.content end

  def get_next_page_appendix_with_index(index)
    @next_page_appendix.gsub("{index}", index.to_s)
  end

  # 記事が何ページまであるかを返す
  def get_page_index_max(node, tag) node.content.to_i end

  # 対象に応じてURLを返す
  def get_content(node, tag, target)
    return get_image_url(node, tag) if target == :image
    return get_image_title(node, tag) if target == :image_title
    return get_title(node, tag) if target == :title
    return get_page_index_max(node, tag) if target == :page_index_max
  end

  # 与えられたURLから、セレクタに従って画像のURLを返す
  def get_contents(url, target, nest = 0)
    css = @selector[target][nest]
    contents = get_doc(url).css(css).inject([]){ |c, node| c << get_content(node, get_last_tag(css), target) }
    return contents if nest >= (@selector[target].length - 1)
    # 得られたURLそれぞれに対して次のセレクタを実行する
    contents.inject([]){ |r, c| r << get_contents(c, target, nest + 1) }.flatten
  rescue => ex
    puts "Error in get_contents: #{ex}"
    return nil
  end
end
