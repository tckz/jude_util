#!/usr/bin/ruby

$KCODE='u'

require 'pp'
require 'optparse'
require 'ostruct'

$:.unshift(File.dirname(__FILE__))
require "lib/jude_util"


include	JudeUtil
include	JudeUtil::XML

options = OpenStruct.new
options.text = false
options.xpath = nil
options.code = nil
options.out = nil
options.fs = "\t"
options.root = "results"
options.pretty = false

OptionParser.new { |opt|
	opt.banner = "usage: #{File.basename($0)} [options] [in.xml...]"
	opt.separator " o input the XML document"
	opt.separator "   o filter the document by XPath expression"
	opt.separator "     o replace filtered nodes to any value which returned by the codeblock"
	opt.separator " o output the result the XML document"
	opt.separator "   o if text-mode, it is output by TSV style."
	opt.separator " "
	opt.separator "Options:"
	opt.on("-x", "--xpath=XPath", "XPath expression. ex. //element[@attr='yy']") do |v|
		options.xpath = v
	end
	opt.on("-o", "--out=FILENAME", "filename to output") do |v|
		options.out = v
	end
	opt.on("--root=TAG", "tagname of root element for output") do |v|
		options.root = v
	end
	opt.on("--pretty", "pretty print for XML") do |v|
		options.pretty = true
	end

	opt.separator " "
	opt.separator "with --xpath option:"
	opt.on("--code=BLOCK", "code block. ex. {|n| n['fullname']}") do |v|
		options.code = v
	end
	opt.on("-t", "--text", "output result by text each line") do |v|
		options.text = true
	end

	opt.separator " "
	opt.separator "with --text option:"
	opt.on("--fs=SEPARATOR", "field separator for text mode") do |v|
		options.fs = v
	end

	begin
		opt.parse!(ARGV)

		if options.code
			begin
				p = eval("Proc.new #{options.code}")
			rescue SyntaxError => ex
				raise ArgumentError, "*** invalid code block:\n#{ex.message}"
			end

			if !p.kind_of?(Proc)
				raise ArgumentError, "*** specify code block"
			end
			options.code = p
		end

		if options.code && !options.xpath
			raise ArgumentError, "*** specify both --code and --xpath"
		end
	rescue ArgumentError, OptionParser::ParseError => ex
		STDERR.puts opt.to_s
		STDERR.puts ""
		STDERR.puts "#{ex.message}"
		exit	1
	end
}


if options.out
	if is_jruby?
		st = java.io.PrintStream.new(options.out)
	else
		st = File.open(options.out, "w")
	end
else
	if is_jruby?
		st = java.lang.System.out
	else
		st = STDOUT
	end
end

if ARGV.size == 0
	ARGV.push(nil)
end

out_doc = XML::new_document
out_doc.root = el_root = out_doc.create_element(options.root)

ARGV.each {|fn_in|

	doc = XML::build_document(fn_in)
	if !options.xpath
		# XPath指定がない場合
		# 読み込んだdocを出力する
		if ARGV.size == 1
			out_doc = doc
		else
			# が、複数のdocが指定されている場合、一個のdocにまとめないと
			# 出力XMLがvalidでなくなるので一個にまとめる
			el_root << out_doc.import_node(doc.root, true)
		end
	else
		# XPath指定がある場合、XPath式でフィルタ
		doc.find(options.xpath).to_a.each_with_index {|node,idx|
			if options.code
				# コードブロックが指定されている場合、フィルタされたノードを引数に
				# コードブロックを実行し結果を得る
				if options.code.arity == 1
					result = options.code.call(node)
				else
					result = options.code.call(node,idx)
				end
			else
				# コードブロックがない場合はフィルタされたノードを結果として扱う
				result = node
			end
	
			# 結果、nilなら無視
			if !result
				next
			end

			result = [result].flatten
			
			if options.text
				# テキストモードの場合、TSVスタイルで出力
				st.print "#{result.join(options.fs)}\n"
			else
				# XML出力の場合は、結果それぞれに対して・・・
				result.each { |item|
					if item.respond_to?(:element?) && item.element?
						# XML要素なら、複製して出力XMLのルートに追加する
						el_root << out_doc.import_node(item, true)
					else
						# 結果を文字列化したものを1要素にして、出力XMLのルートに追加
						el_result = out_doc.create_element("result") 
						el_result << item.to_s
						el_root << el_result
					end
				}
			end
		}
	
	end

}

# 出力XMLを書き出す
# テキストモードの場合、都度書き出しているので出力不要
if !options.text
	XML::write_document(out_doc, st, "utf-8", false, options.pretty)
end

exit 0

# vi: ts=2 sw=2

