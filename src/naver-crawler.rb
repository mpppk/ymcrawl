require_relative 'crawler'

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
