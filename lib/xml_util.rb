# = XMLアクセスI/Fの再定義
# jrubyとCRubyで同じI/F（libxml-ruby風）が使えるように
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

begin
	require 'java'
rescue LoadError
end
if defined?(JavaUtilities)
	require "xml_util/java"
else
	require "xml_util/libxml"
end


# vi: ts=2 sw=2 noexpandtab


