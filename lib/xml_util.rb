# = XMLアクセスI/Fの再定義
# jrubyとCRubyで同じI/F（libxml-ruby風）が使えるように
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

if is_jruby?
	require "lib/xml_util_java"
else
	require "lib/xml_util_libxml"
end


# vi: ts=2 sw=2 noexpandtab


