#!/usr/bin/ruby

# = estimate_list.rb: retrieve <<control>> <<boundary>> classes from the xml
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

	class	EstimateList

		include	JudeUtil

		def	initialize(root, options)
			@root = root
			@options = options
		end

		def	out_list(io)
			self.create_list.each { |cols|
				self.esc_out(cols, io)
			}
		end

		def	create_list()
			lines = []

			targets = self.which_is_target(@root, @options)

			parent_pkgs = {}

			targets.each { |e|
				name = self.get_name(e)
				fullname = self.get_fullname(e)
				namespace = self.get_namespace(e)

				if namespace != "" && !parent_pkgs[namespace]
					pkg = self.get_parent(e)
					if !@options.wo_pkg
						lines.push(
							[
								namespace, "", 
								0, namespace, namespace, 
								"", 
								# APIの仕様でパッケージ配下の図中のコメントが紐づくので「定義」のみに絞る
								self.make_desc(pkg, "\n--\n", true),
								"",
								"",
								"",
							]
						)
					end
					parent_pkgs[namespace] = pkg
				end

				# 説明
				desc = self.make_desc(e, "\n--\n", @options.definition_only)

				# 汎化
				generalizations = []
				e.find("./generalizations/generalization").each { |g|
					generalizations.push(g["super"])
				}
				generalization = generalizations.join("\n")

				num = 1
				cols = [
					"", name, 
					num.to_s, namespace, fullname, 
					"", 
					desc,
					generalization,
					self.get_estimate_value(e, "@d"),
					self.get_estimate_value(e, "@m"),
				]

				lines.push(cols)


				# 属性
				e.find("./attributes/attribute").each { |a|
					num = num + 1
					cols = [
						"", "", 
						num.to_s, namespace, fullname,
						self.get_name(a),
						self.make_desc(a, "\n--\n", @options.definition_only),
						"",
						self.get_estimate_value(a, "@d"),
						self.get_estimate_value(a, "@m"),
					]
					lines.push(cols)
				}

				# 操作
				e.find("./operations/operation").each { |o|
					num = num + 1
					cols = [
						"", "", 
						num.to_s, namespace, fullname,
						self.get_name(o) + "()",
						self.make_desc(o, "\n--\n", @options.definition_only),
						"",
						self.get_estimate_value(o, "@d"),
						self.get_estimate_value(o, "@m"),
					]
					lines.push(cols)
				}
				

			}

			lines
			
		end

		# 当該要素に記載済みの見積り値を返す
		# 単位や数字をどう使うかは、利用者次第
		# 複数ある場合は最初の一個が適用される
		#
		# 該当するアノテーションが存在しない場合空文字
		#
		# @d
		#   設計見積り
		# @m
		#   製造見積り
		# 
		# e::
		#  要素
		# key::
		#  アノテーションキー。"@m"とか"@d"
		def	get_estimate_value(e, key)
			v = ""
			ans = self.find_annotations(e, "@key='#{key}'")
			if ans.size > 0
				v = ans.first.child.to_s
			end

			return	v
		end

		# 出力対象となるClassを探して返す
		# stereotype=boundary|controlなClassのリスト
		# Classに@since指定がある場合、オプション指定と比較して取捨選択
		#
		# 処理対象classを表すElementの配列を返す
		#
		# root::	
		#  走査を開始するXML要素
		# options::
		#  解析済み実行時オプション
		#
		def	which_is_target(root, options)
			self.select_target(root, "//class[./stereotypes/stereotype[text()='boundary' or text()='control']]", options).find_all { |e|
				!(self.find_annotations(e, "@key='@noest'").size > 0)
			}
		end

		def	self.main(argv)

			# オプションのデフォルト値
			options = OpenStruct.new
			options.encode = "utf-8"
			options.since = nil
			options.fn_out = nil
			options.use_alias1 = nil
			options.fullname = nil
			options.definition_only = nil

			# オプション
			OptionParser.new { |opt|
				opt.banner = "usage: #{File.basename($0)} [options] [filename]"
				opt.separator ""
				opt.separator " o use STDIN instead of file if filename was ommited."
				opt.separator ""
				opt.separator "Options:"

				opt.on("--definition-only", "use desc looked up from only definition") do |v|
					options.definition_only = true
				end

				opt.on("-e", "--encoding=ENCODING-NAME", "default: #{options.encode}") do |v|
					options.encode = v
				end

				opt.on("-f", "--fullname=REGEX", "criteria for fullname") do |v|
					options.fullname = v
				end

				opt.on("-o", "--out=filename", "filename for output") do |v|
					options.fn_out = v
				end

				opt.on("-s", "--since=REGEX", "criteria for @since") do |v|
					options.since = v
				end

				opt.on("-a", "--use-alias1", "use alias1 to identifiers") do |v|
					options.use_alias1 = true
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

				ml = JudeUtil::EstimateList.new(doc.root, options)

				ml.out_list(io_out)
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
	exit	JudeUtil::EstimateList::main(ARGV)
end




# vi: ts=2 sw=2 noexpandtab
