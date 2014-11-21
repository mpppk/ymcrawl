require_relative 'crawler'
require_relative 'dropbox.rb'
require 'optparse'
require 'json'
require 'zipruby'
require 'find'
require 'kconv'

option={}
OptionParser.new do |opt|
  opt.on('--debug', 'YMCrawl.debugを読み込む'){|v| option[:debug] = v}
  opt.parse!(ARGV)
end

class Uploader
	def initialize(setting)
		@uploader_name = setting[:save_to]
		@uploader_data = setting[:uploader][ setting[:save_to].to_sym ]
		@app_key       = @uploader_data[:app_key]
		@app_secret    = @uploader_data[:app_secret]
		@access_token    = @uploader_data[:access_token]
		@uploader      = get_uploader
	end

	# 引数に応じてアップロード先のインスタンスを返す
	def get_uploader
		return @uploader unless @uploader == nil
		return DropboxManager.new(@app_key, @app_secret) if @uploader_name == "dropbox"
		raise ArgumentError("uploader #{uploader_name} is not found")
	end

	def get_logined_uploader
		@uploader = get_uploader
		token = (@access_token == "") ? @uploader.get_access_token : @access_token
		new_token  = @uploader.login( token )
		if @access_token == ""
			@access_token = new_token 
			open(SETTING_FILE_PASS, 'w') do |io|
			  JSON.dump(setting, io)
			end
		end
		@uploader
	end
end

# 引数に指定されたディレクトリを中身ごと消す
def remove_dir(dir)
	# サブディレクトリを階層が深い順にソートした配列を作成
	dirlist = Dir::glob(dir + "**/").sort {
	  |a,b| b.split('/').size <=> a.split('/').size
	}

	# サブディレクトリ配下の全ファイルを削除後、サブディレクトリを削除
	dirlist.each {|d|
	  Dir::foreach(d) {|f|
	    File::delete(d+f) if ! (/\.+$/ =~ f)
	  }
	  Dir::rmdir(d)
	}

	return nil unless File.exist?(dir)
	# 指定したディレクトリ下のファイルを削除
	Dir::foreach(dir) {|f|
	  File::delete("#{dir}/#{f.toutf8}") if ! (/\.+$/ =~ f)
	}
    Dir::rmdir(dir)
end

# 指定されたディレクトリ以下のファイルをzipにする。返り値はzipのパス
def zip_dir(src)
	dst = "#{src}.zip"
	Zip::Archive.open(dst, Zip::CREATE) do |ar|
		Dir.glob("#{src}/*").each do |item|
			ar.add_file(item)
		end
	end
	dst
end

ORG_SETTING_FILE_PASS  = "YMCrawlfile"
SETTING_FILE_PASS      = (option.key?(:debug)) ? "#{ORG_SETTING_FILE_PASS}.debug" : ORG_SETTING_FILE_PASS
SITE_JSON_NAME         = "site.json"

setting        = JSON.parse( File.open(SETTING_FILE_PASS).read, {:symbolize_names => true} )
json_file_pass = FileTest.exist?(SITE_JSON_NAME) ? SITE_JSON_NAME : setting[:site_json]
puts "reading site json file from #{json_file_pass}"
json           = JSON.parse( open(json_file_pass).read, {:symbolize_names => true} )
File.write( SITE_JSON_NAME, JSON.unparse(json) ) unless FileTest.exist?(SITE_JSON_NAME)
crawler        = Crawler.new(setting[:dst_dir], json[:naver], setting[:wait_time])
file_dirs      = ARGV.map{ |v| crawler.save_images(v) }
exit if setting[:save_to] == "local"

zip_dirs   = file_dirs.map{ |dir| zip_dir(dir) }
file_dirs.each{ |dir| remove_dir(dir) }

uploader = Uploader.new(setting).get_logined_uploader
zip_dirs.each do |dir|
  puts "uploading #{dir} to dropbox"
  uploader.put([dir])
end
