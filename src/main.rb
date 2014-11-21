require_relative 'crawler'
require_relative 'mydropbox.rb'
require 'json'
require 'zipruby'
require 'find'
require 'kconv'

def remove_dir(dir)
	puts "remove: #{dir}"
	# サブディレクトリを階層が深い順にソートした配列を作成
	dirlist = Dir::glob(dir + "**/").sort {
	  |a,b| b.split('/').size <=> a.split('/').size
	}
	puts "dirlist: #{dirlist}"

	# サブディレクトリ配下の全ファイルを削除後、サブディレクトリを削除
	dirlist.each {|d|
	  Dir::foreach(d) {|f|
	  	puts "remove file: #{f}"
	    File::delete(d+f) if ! (/\.+$/ =~ f)
	  }
	  Dir::rmdir(d)
	}

	# 指定したディレクトリ下のファイルを削除
	Dir::foreach(dir) {|f|
      puts "remove file: #{f}"
	  File::delete("#{dir}/#{f.toutf8}") if ! (/\.+$/ =~ f)
	}
    Dir::rmdir(dir)
end

def get_uploader(uploader_name)
	return DropboxManager.new if uploader_name == "dropbox"
	raise ArgumentError("uploader #{uploader_name} is not found")
end

def zip_dir(src)
	puts "zip: #{src}"
	dst = "#{src}.zip"
	Zip::Archive.open(dst, Zip::CREATE) do |ar|
		Dir.glob("#{src}/*").each do |item|
			ar.add_file(item)
		end
	end
	dst
end

def make_zip(target, zippath)
  puts "target: #{target}"
  puts "zippath: #{zippath}"
  Zip::Archive.open(zippath, Zip::CREATE) do |ar|      
    if File.directory?(target)
      target = (target + "/").sub("//", "/")
      Dir::chdir(target) do
        Dir.glob("**/*") do |file|
          if File.directory?(file)
            ar.add_dir(target+file)
          else
            ar.add_file(target+file, file)
          end
        end
      end     
    else
      ar.add_file(target)
    end
     
  end
end

SITE_JSON_NAME         = "site.json"
ACCESS_TOKEN_FILE_NAME = "token.json"

setting        = JSON.parse( File.open("YMCrawlfile").read, {:symbolize_names => true} )
json_file_pass = FileTest.exist?(SITE_JSON_NAME) ? SITE_JSON_NAME : setting[:site_json]
puts "reading site json file from #{json_file_pass}"
json           = JSON.parse( open(json_file_pass).read, {:symbolize_names => true} )
File.write( SITE_JSON_NAME, JSON.unparse(json) ) unless FileTest.exist?(SITE_JSON_NAME)
crawler        = Crawler.new(setting[:dst_dir], json[:naver], setting[:wait_time])
file_dirs      = ARGV.map{ |v| crawler.save_images(v) }
exit if setting[:save_to] == "dropbox"
zip_dirs   = file_dirs.map{ |dir| zip_dir(dir) }
# zip_dirs   = file_dirs.map{ |dir| make_zip(dir, File::basename(dir) + ".zip") }
file_dirs.each{ |dir| remove_dir(dir) }
# file_dirs.each{ |dir| FileUtils::remove_entry(dir, true) }
# token_data = JSON.parse( File.open(ACCESS_TOKEN_FILE_NAME).read, {:symbolize_names => true} )
# uploader   = get_uploader(setting[:save_to])
# token      = token_data[ setting[:save_to].to_sym ]
# new_token  = uploader.login( token )
# token_data[ setting[:save_to].to_sym ] = new_token if new_token != token
# zip_dirs.each{ |dir| uploader.put([dir, File::basename(dir)]) }
# uploader.put([zip, "test.jpg"])
