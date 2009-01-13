#!/usr/bin/ruby

# = import_ermodel.rb: import csv and create EREntities/Attributes/Domain
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

# jrubyで実行します

$KCODE='u'

require 'optparse'
require 'ostruct'
require 'pp'
require 'csv'
require 'iconv'
require 'java'

$:.unshift(File.dirname(__FILE__))
require "lib/jude_util"
require "lib/jude_api"

module	JudeUtil

	# CSVで記述したERモデル（エンティティ名と属性のリスト）をjudeにインポート
	class	ImportERModel

		include	JudeAPIUtil
		include	ShortCutJudeProject
		include	ModelEditor

		def	initialize(root, options)
			@root = root
			@options = options

			self.load_short_cut(@root)
		end

		# CSVを読み込んでエンティティとしてインポート
		#
		# fn::
		#   入力CSVファイル名
		def	import(fn)
			# ERモデルがまだない場合は作成する
			if !self.find_er_model
				# TODO: ここでJUDE付属sampleのように"ER Model"を指定すると
				# 手動（JUDEのUI）で作ったJUDEプロジェクトとマージできなかった。
				# 手動で作ったJUDEプロジェクトだと下記の通り日本語で入ってた。
				#
				# 逆に言えば、このコードだと英語環境で作ったJudeプロジェクトと
				# マージできないってことになりそう。
				self.er_model_editor.createERModel(@root, "ERモデル")
				self.load_short_cut(@root)
			end

			header = {}
			attributes = []
			entity = {
				:file => fn,
				:logicalname => "",
				:physicalname => "",
				:attributes => attributes,
			}

			ic = Iconv.new("utf-8", @options.encode)
			# Java5なjruby1.1.3環境において、
			# 一文字に対してiconvすると変換結果が空文字になるケースがあったので、
			# 全体をまとめて変換することにした。
			contents = ic.iconv(File.open(fn, "r").read)
			line_count = 0
			CSV::StringReader.new(contents, @options.fs).each { |row|
				line_count = line_count + 1

				# 空行だとNil
				if !row
					next
				end

				if header.size == 0
					if row[0] =~ /^#/ 
						# ヘッダ
						row[0].gsub!(/^#/, "")

						# TODO: 列位置決めウチ
						if row[0] =~ /^@entity/
							entity[:logicalname] = row[1].to_s.strip
							entity[:physicalname] = row[2].to_s.strip
							next
						else
							row.each_with_index { |col, idx|
								header[idx] = col.strip.intern
							}
						end
					end
				else
					if row.size <= 1 || row[0] =~ /^#/
						next
					end
					rec = {
						:line => line_count,
					}
					header.each_pair { |idx, v|
						rec[v] = row[idx].to_s.strip
					}
					attributes.push(rec)
				end
			}

			begin
				self.create_entity(entity)
			rescue NativeException => ex
				raise "#{entity[:logicalname]}(file=#{fn}): #{ex.cause.message}"
			rescue RuntimeError => ex
				raise "#{entity[:logicalname]}(file=#{fn}): #{ex.message}"
			end
		end

		# エンティティ一個分作成
		#
		#	e = {
		#		:logicalname => 論理名,
		#		:physicalname => 物理名,
		#		:attributes => [
		#			{
		#				:physicalname => 物理名,
		#				:logicalname => 論理名,
		#				:length	=> 長さ,
		#				:type	=> データ型名,
		#			}, ...
		#		],
		#	}
		#
		# e::
		#   作成するエンティティの情報が入ったHash
		def	create_entity(e)
			sch = self.find_er_schema

			if e[:logicalname].to_s == ""
				raise "entity's logicalname must be specified."
			end

			ent = self.er_model_editor.createEREntity(sch, e[:logicalname], e[:physicalname].to_s)

			# 属性
			e[:attributes].each {|a|
				begin
					er_attr = self.update_attribute(ent, nil, e, a, @options)
				rescue NativeException => ex
					raise "#{a[:logicalname]}(line=#{a[:line]}): #{ex.cause.message}"
				rescue RuntimeError => ex
					raise "#{a[:logicalname]}(line=#{a[:line]}): #{ex.message}"
				end
			}

			ent
		end

		def	self.main(argv)

			ec = 1

			options = OpenStruct.new
			options.encode = "shift_jis"
			options.fn_out = nil
			options.fs = "\t"
			options.domain_datatype = "INT"

			# オプション
			OptionParser.new { |opt|
				opt.banner = "usage: #{File.basename($0)} [options] csv-filename..."
				opt.separator ""
				opt.separator "Options:"

				opt.on("--domain-datatype=DATATYPE", "datatype for created domain(default:#{options.domain_datatype})") do |v|
					options.domain_datatype = v
				end

				opt.on("--fs=field-separator", "sep for cols(default: HT)") do |v|
					options.fs = v
				end

				opt.on("-e", "--encoding=ENCODING-NAME", "default: #{options.encode}") do |v|
					options.encode = v
				end

				opt.on("-o", "--out=file.jude", "jude filename to modify") do |v|
					options.fn_out = v
				end


				begin
					opt.parse!(argv)

					if !options.fn_out
						raise ArgumentError, "-o must be specified."
					end
				rescue ArgumentError, OptionParser::ParseError => e
					STDERR.puts opt.to_s
					STDERR.puts ""
					STDERR.puts "#{e.message}"
					return	ec
				end
			}

			pa = JudeAPIUtil::open_jude(options.fn_out, false)

			begin
				im = JudeUtil::ImportERModel.new(pa.project, options)

				do_txn {
					argv.each {|a|
						im.import(a)
					}
				}
				pa.save()

				ec = 0
			rescue RuntimeError => ex
				STDERR.puts ex.message
			ensure
				pa.close
			end

			return	ec
		end
	end
end


if $0 == __FILE__
	include	JudeUtil
	include	JudeAPIUtil
	include	ModelEditor

	Version = JudeUtil::Version
	exit	JudeUtil::ImportERModel::main(ARGV)
end

# vi: ts=2 sw=2

