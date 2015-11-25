gem uninstall -x flash_flow
gem build flash_flow.gemspec
export VERSION=`ruby -r./lib/flash_flow/version -e "puts FlashFlow::VERSION"`
gem install flash_flow-$VERSION.gem --no-ri --no-rdoc
rbenv rehash
