# Install this the SDK with "gem install dropbox-sdk"
require 'dropbox_sdk'

class DropboxManager

	def initialize(app_key, app_sec)
		@app_key = app_key
		@app_sec = app_sec
		@client = nil
		@access_token = nil
	end

	def login(arg_access_token = nil)
		if not @client.nil?
			puts "already logged in!"
			return @access_token
		end

		@access_token = (arg_access_token == nil) ? get_access_token : arg_access_token
		begin
			@client = DropboxClient.new(@access_token)
			return @access_token
		rescue DropboxError => ex
			puts "access token is invalid"
			@access_token = get_access_token
			@client = DropboxClient.new(get_access_token)
			return @access_token
		end
	end
	
	def get_access_token
		web_auth = DropboxOAuth2FlowNoRedirect.new(@app_key, @app_sec)
		authorize_url = web_auth.start()
		puts "1. Go to: #{authorize_url}"
		puts "2. Click \"Allow\" (you might have to log in first)."
		puts "3. Copy the authorization code."

		print "Enter the authorization code here: "
		STDOUT.flush
		auth_code = STDIN.gets.strip

		access_token, user_id = web_auth.finish(auth_code)

		# DropboxClient.new(access_token)
		puts "You are logged in.  Your access token is #{access_token}."
		access_token
	end

	def put(command)
		fname = command[0]

		#If the user didn't specifiy the file name, just use the name of the file on disk
		if command[1]
			new_name = command[1]
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
