require 'open-uri'
require 'nokogiri'
require 'kconv'
require 'addressable/uri'

class Crawler
  def initialize(dir, site_data)
    @selector = {}
    @selector[:image] = site_data["css"]["image"]
    @selector[:image_title] = site_data["css"]["image_title"]
    @selector[:title] = site_data["css"]["title"]
    @dir = dir
  end
  
  # 与えられたcssセレクタから画像を抽出する
  def save_images(url)
    dst_dir = "#{@dir}/#{get_contents(url, :title).first}"
    get_contents(url, :image).zip(get_contents(url, :image_title)) { |url, title| save_image(dst_dir, url, title) }
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
  def save_image(dst_dir, url, title)
    puts "src: #{url}"
    # ready filepath
    filename = "#{title}#{File.extname(url)}"
    cnt = 0
    filePath = "#{dst_dir}/#{get_unique_name(filename)}"
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

  # 対象に応じてURLを返す
  def get_content(node, tag, target)
    return get_image_url(node, tag) if target == :image
    return get_image_title(node, tag) if target == :image_title
    return get_title(node, tag) if target == :title
  end

  # 与えられたURLから、セレクタに従って画像のURLを返す
  def get_contents(url, target, nest = 0)
    css = @selector[target][nest]
    contents = []
    get_doc(url).css(css).each{ |node| contents << get_content(node, get_last_tag(css), target) }
    return contents if nest >= (@selector[target].length - 1)
    child_content = []
    # 得られたURLそれぞれに対して次のセレクタを実行する
    contents.each{ |content| child_content << get_contents(content, target, nest + 1) }
    child_content.flatten
  end
end
