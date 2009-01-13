#!/usr/bin/ruby

# = add_identifier.rb: add identifier attribute(ex. 'ID') to ER entities
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

# jrubyで実行します

$KCODE='u'

require 'optparse'
require 'ostruct'
require 'pp'
require 'java'

$:.unshift(File.dirname(__FILE__))
require "lib/jude_util"
require "lib/jude_api"

module	JudeUtil

	# ERエンティティにIdentifierな属性を追加する
	class	AddIdentifier

		include	JudeAPIUtil
		include	ShortCutJudeProject
		include ModelEditor

		def	initialize(root, options)
			@root = root
			@options = options

			self.load_short_cut(@root)
		end

		# エンティティにIdentifierな属性追加
		#
		# fn::
		#   入力したJUDEファイル名
		def	do_add(fn)

			entity = {}

			begin
				self.enum_er_entities.each {|ent|
					entity[:logicalname] = ent.logicalName.to_s
					entity[:physicalname] = ent.physicalName.to_s

					if ent.primaryKeys.size >= 2 
						# 2列以上の主キーが既にある場合はスキップ
						next
					end

					a = {
						:logicalname => self.make_identifier_name(@options.attr_name, entity[:logicalname]),
						:physicalname => "",
						:nn => nil,
						:default => nil,
						:pk => "Y",
						:domain => nil,
						:type => nil,
						:length => nil,
					}

					# 既に同じ名前の属性があるか
					attr_found = (ent.primaryKeys.to_a + ent.nonPrimaryKeys.to_a).find_all {|k|
						k.logicalName == a[:logicalname]
					}.first

					# 同じ名前のキーがなく、主キーが1列だけ存在する場合、
					if !attr_found && ent.primaryKeys.size == 1
						if !@options.force
							next
						end
						# 上書きオプションが有効なら
						# 当該属性をIdentifierとして書き換える
						attr_found = ent.primaryKeys.first
					end

					if attr_found
						# 現在の属性の情報を保存
						a[:physicalname] = attr_found.physicalName.to_s
						a[:default] = attr_found.defaultValue
						a[:nn] = attr_found.isNotNull ? "Y" : ""
						if attr_found.domain
							a[:domain] = attr_found.domain.logicalName
						else
							a[:type] = attr_found.datatype.logicalName
							a[:length] = attr_found.lengthPrecision
						end
					end

					if @options.attr_name_physical
						# 物理名フォーマットが指定された場合
						# 物理名をつける
						a[:physicalname] = self.make_identifier_name(@options.attr_name_physical, entity[:physicalname])
					end


					if @options.domain
						# ドメイン指定の場合
						a[:domain] = @options.domain
						a[:type] = @options.domain_datatype
					else
						# データ型指定の場合
						a[:type] = @options.datatype
					end

					#pp a
					self.update_attribute(ent, attr_found, entity, a, @options)
				}
			rescue NativeException => ex
				raise "#{entity[:logicalname]}(file=#{fn}): #{ex.cause.message}"
			rescue RuntimeError => ex
				raise "#{entity[:logicalname]}(file=#{fn}): #{ex.message}"
			end
		end

		# エンティティ名と属性のベース名からIdentifier列の名前を返す
		#
		# baseに%eを含む場合、エンティティ名に置き換える
		def make_identifier_name(base, entity_name)
			ret = base.gsub(/%e/, entity_name.to_s)

			ret
		end


		def	self.main(argv)

			options = OpenStruct.new
			options.domain_datatype = "INT"
			options.domain = nil
			options.force = nil
			options.datatype = "INT"
			options.attr_name = "ID"
			options.attr_name_physical = nil

			# オプション
			OptionParser.new { |opt|
				opt.banner = "usage: #{File.basename($0)} [options]"
				opt.separator ""
				opt.separator "Options:"

				opt.on("--force", "force override primary key(only one column)") do |v|
					options.force = true
				end

				opt.on("--attr-name=NAME", "name for created attr(ex. 'ID', '%e_id')") do |v|
					options.attr_name = v
				end

				opt.on("--attr-name-physical=NAME", "physical name for created attr") do |v|
					options.attr_name_physical = v
				end

				opt.on("--datatype=DATATYPE", "datatype for created attr(default:#{options.datatype})") do |v|
					options.datatype = v
				end

				opt.on("--domain=DOMAIN", "domain for created attr") do |v|
					options.domain = v
				end

				opt.on("--domain-datatype=DATATYPE", "datatype for created domain(default:#{options.domain_datatype})") do |v|
					options.domain_datatype = v
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


			ec = 0
			argv.each {|jude|
				pa = nil
				begin
					pa = JudeAPIUtil::open_jude(jude, false)
					app = JudeUtil::AddIdentifier.new(pa.project, options)

					do_txn {
							app.do_add(jude)
					}
					pa.save()

				rescue RuntimeError => ex
					STDERR.puts ex.message
					ec = 1
					break
				ensure
					if pa
						pa.close
					end
				end
			}

			return	ec
		end
	end
end


if $0 == __FILE__
	include	JudeUtil
	include	JudeAPIUtil
	include	ModelEditor

	Version = JudeUtil::Version
	exit	JudeUtil::AddIdentifier::main(ARGV)
end

# vi: ts=2 sw=2

