# Install this the SDK with "gem install dropbox-sdk"
require 'dropbox_sdk'

# Get your app key and secret from the Dropbox developer website
APP_KEY = ''
APP_SECRET = ''

class DropboxManager
	def initialize
    if APP_KEY == '' or APP_SECRET == ''
      puts "You must set your APP_KEY and APP_SECRET in cli_example.rb!"
      puts "Find this in your apps page at https://www.dropbox.com/developers/"
      exit
    end
    @client = nil
	end

	def login
		if not @client.nil?
			puts "already logged in!"
		else
			web_auth = DropboxOAuth2FlowNoRedirect.new(APP_KEY, APP_SECRET)
			authorize_url = web_auth.start()
			puts "1. Go to: #{authorize_url}"
			puts "2. Click \"Allow\" (you might have to log in first)."
			puts "3. Copy the authorization code."

			print "Enter the authorization code here: "
			STDOUT.flush
			auth_code = STDIN.gets.strip

			access_token, user_id = web_auth.finish(auth_code)

			@client = DropboxClient.new(access_token)
			puts "You are logged in.  Your access token is #{access_token}."
		end
	end

	def put(command)
    fname = command[1]

    #If the user didn't specifiy the file name, just use the name of the file on disk
    if command[2]
      new_name = command[2]
    else
      new_name = File.basename(fname)
    end

    if fname && !fname.empty? && File.exists?(fname) && (File.ftype(fname) == 'file') && File.stat(fname).readable?
      #This is where we call the the Dropbox Client
      pp @client.put_file(new_name, open(fname))
    else
      puts "couldn't find the file #{ fname }"
    end
	end
end

dm = DropboxManager.new
dm.login
puts "put file test.jpg"
dm.put(["test.jpg", "test.jpg"])


