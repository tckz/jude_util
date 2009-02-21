#!/usr/bin/ruby

# = model2crud.rb: retrieve CRUD info about entities from the xml
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

require 'optparse'
require 'ostruct'
require 'pp'

$:.unshift(File.join(File.dirname(__FILE__), "lib"))
require "jude_util"
require "xml_util"

module	JudeUtil

	class	Model2CRUD

		include	JudeUtil

		def	initialize(root, options)
			@root = root
			@options = options
		end

		def	out_list(io)
			self.crud_list.each { |cols|
				self.esc_out(cols, io)
			}
		end

		# CRUDリスト
		def	crud_list()

			lines = []

			# モデル/ユースケースとCRUDの対応をロード
			crud_info = self.load_crud(@root, @options)
			#pp crud_info

			# { "C" => 1, "R" => 1 }なハッシュを [ "C", "R", "", "" ] な配列に
			crud2array = Proc.new { |cruds|
				mark2index = {
					"C" => 0,
					"R" => 1,
					"U" => 2,
					"D" => 3,
				}
				ret = Array.new(mark2index.keys.size)
				cruds.keys.each { |mark|
					if mark2index[mark]
						ret[mark2index[mark]] = mark
					end
				}
				ret
			}

			# refs #6 キーを名前からIDに変えたのでソートキーを合わせる必要がある
			# ソート対象要素が1の場合、比較関数が呼ばれないので、このhashに名前が
			# 入らない。なので、id2nameはあくまで名前の保存庫。名前へのアクセスには
			# get_name利用で
			id2name = {}
			get_name = Proc.new { |id|
				if !id2name[id]
					id2name[id] = self.get_fullname(@root.find("//*[@jude_id='#{id}']").first)
				end

				id2name[id]
			}

			# jrubyとCRubyで順番が違ってたのでソートすることに
			crud_info[:model2crud].keys.sort{|a,b| get_name.call(a) <=> get_name.call(b)}.each{ |model_id|
				cruds = crud_info[:model2crud][model_id]

				# ユースケース併記時のCRUD表記の列位置に合わせ空列を足した
				lines.push([ get_name.call(model_id), "" ] + crud2array.call(cruds))

				# モデルに対するユースケースとその操作を併記
				if @options.with_usecase
					crud_info[:model2usecase][model_id].keys.sort{|a,b| get_name.call(a) <=> get_name.call(b)}.each { |uc_id|
						cruds = crud_info[:model2usecase][model_id][uc_id]
						lines.push(["", get_name.call(uc_id)] + crud2array.call(cruds))
					}
				end
			}

			lines
		end

		def	self.main(argv)

			options = OpenStruct.new
			options.encode = "utf-8"
			options.since = nil
			options.fn_out = nil
			options.use_alias1 = nil
			options.use_physical_name = nil
			options.fullname = nil
			options.with_usecase = nil

			# オプション
			OptionParser.new { |opt|
				opt.banner = "usage: #{File.basename($0)} [options] [in.xml]"
				opt.separator ""
				opt.separator " o retrieve model-list and CRUD-info for each model"
				opt.separator " o use STDIN instead of file if in.xml was ommited."
				opt.separator ""
				opt.separator "Options:"

				opt.on("-u", "--with-usecase", "list usecases that is attached to the model") do |v|
					options.with_usecase = true
				end

				opt.on("-e", "--encoding=ENCODING-NAME", "default: #{options.encode}") do |v|
					options.encode = v
				end
			
				opt.on("-f", "--fullname=REGEX", "criteria for fullname") do |v|
					options.fullname = v
				end

				opt.on("-o", "--out=FILENAME", "filename for output") do |v|
					options.fn_out = v
				end

				opt.on("-s", "--since=REGEX", "criteria for @since") do |v|
					options.since = v
				end

				opt.on("-a", "--use-alias1", "use alias1 to identifiers") do |v|
					options.use_alias1 = true
				end

				opt.on("--use-physical-name", "use physical-name to identifiers") do |v|
					options.use_physical_name = true
				end

				begin
					opt.parse!(argv)
				rescue ArgumentError, OptionParser::ParseError => e
					STDERR.puts opt.to_s
					STDERR.puts ""
					STDERR.puts "#{e.message}"
					return	1
				end
			}

			fn_in = argv[0]

			doc = XMLUtil::XML::build_document(fn_in)

			fp_out = nil
			begin
				if options.fn_out
					io_out = fp_out = File.new(options.fn_out, "w")
				else
					io_out = STDOUT
				end
				io_out.extend(TextConverter).from_to("utf-8", options.encode)

				cl = JudeUtil::Model2CRUD.new(doc.root, options)

				cl.out_list(io_out)
			ensure
				if fp_out
					fp_out.close
				end
			end

			0
		end
	end
end





if $0 == __FILE__
	include	JudeUtil
	include	XMLUtil::XML

	Version = JudeUtil::Version
	exit	JudeUtil::Model2CRUD::main(ARGV)
end


# vi: ts=2 sw=2

