cat <<__EOT__
arguments:
  $1
  $2
  $3
  $4
nums: $#
__EOT__
sudo docker run -it --rm -v "$(pwd)":/usr/src/myapp -w /usr/src/myapp mpppk/ymcrawl $1 $2 $3 $4