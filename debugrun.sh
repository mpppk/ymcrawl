sudo docker run -it --rm -v "$(pwd)":/usr/src/myapp -w /usr/src/myapp mpppk/ymcrawl ruby src/main.rb $1