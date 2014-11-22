require_relative 'crawler'
require_relative 'dropbox.rb'
require 'optparse'
require 'json'
require 'zipruby'
require 'find'
require 'kconv'
require 'json-schema'

option={}
OptionParser.new do |opt|
  opt.on('--debug', 'YMCrawl.debugを読み込む'){|v| option[:debug] = v}
  opt.parse!(ARGV)
end

class Uploader
	def initialize(setting)
		@setting       = setting
		@uploader_name = @setting["save_to"]
		@uploader_data = @setting["uploader"][ @setting["save_to"] ]
		puts "uploader validate: " + JSON::Validator.validate(UPLOADER_SCHEMA_FILE_PASS, @uploader_data, :insert_defaults => true).to_s
		@app_key       = @uploader_data["app_key"]
		@app_secret    = @uploader_data["app_secret"]
		@access_token  = @uploader_data["access_token"]
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
			@uploader_data["access_token"] = new_token
			puts "add access token to #{SETTING_FILE_PASS}"
			open(SETTING_FILE_PASS, 'w') do |io|
			  JSON.dump(@setting, io)
			end
		end
		@uploader
	end
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

ORG_SETTING_FILE_PASS     = "YMCrawlfile"
SETTING_FILE_PASS         = (option.key?(:debug)) ? "#{ORG_SETTING_FILE_PASS}.debug" : ORG_SETTING_FILE_PASS
SCHEMA_FILE_PASS          = "YMCrawl_schema.json"
UPLOADER_SCHEMA_FILE_PASS = "uploader_schema.json"
SITE_JSON_NAME            = "site.json"

setting        = JSON.parse( File.open(SETTING_FILE_PASS).read)
puts "json validate: " + JSON::Validator.validate(SCHEMA_FILE_PASS, setting, :insert_defaults => true).to_s

site_json_file_pass = FileTest.exist?(SITE_JSON_NAME) ? SITE_JSON_NAME : setting["site_json"]
puts "reading site json file from #{site_json_file_pass}"
site_json           = JSON.parse( open(site_json_file_pass).read)
File.write( SITE_JSON_NAME, JSON.unparse(site_json) ) unless FileTest.exist?(SITE_JSON_NAME)
crawler   = Crawler.new(setting["dst_dir"], site_json["naver"], setting["wait_time"])
file_dirs = ARGV.map{ |v| crawler.save_images(v) }
exit if setting["save_to"] == "local"

zip_paths   = file_dirs.map{ |dir| zip_dir(dir) }
file_dirs.each{ |dir| FileUtils::remove_entry_secure( dir.force_encoding("ascii-8bit") ) }

uploader = Uploader.new(setting).get_logined_uploader
zip_paths.each do |path|
  puts "uploading #{path} to dropbox"
  uploader.put([path])
  File::delete(path)
end
