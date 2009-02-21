#!/usr/bin/ruby

# = create_sql.rb: create various DDL SQL from entities.
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

require 'optparse'
require 'ostruct'
require 'pp'
require 'yaml'

$:.unshift(File.join(File.dirname(__FILE__), "lib"))
require "jude_util"
require "xml_util"


module	JudeUtil

	class	SqlBuilder

		include	JudeUtil

		# SQL構文の違いに対応するクラス、の基底クラス
		class	SqlDialect
			def	drop_table(table)
				"DROP TABLE #{table} CASCADE;"
			end

			def	create_index(table, type, index_name, cols)
				"CREATE #{type.to_s.upcase} INDEX #{index_name} ON #{table} ( #{cols.join(", ")} );"
			end

			def	drop_index(table, index_name)
				"DROP INDEX #{index_name};"
			end

			def	add_fk(child, child_cols, parent, parent_cols, constraint_name)
				"ALTER TABLE #{child} ADD CONSTRAINT #{constraint_name} FOREIGN KEY (#{child_cols.join(',')}) REFERENCES #{parent}(#{parent_cols.join(',')});"
			end

			def	drop_fk(table, constraint_name)
				"ALTER TABLE #{table} DROP CONSTRAINT #{constraint_name};"
			end
		end

		# コンストラクタ
		#
		# root::
		#  生成元となる文書のroot
		# options::
		#  動作オプション指定
		def	initialize(root, options)
			@root = root
			@options = options

			@options.typemap = {}
			@options.defaultmap = {}

			@sql_dialect = SqlDialect.new

			if @options.fn_map
				map = YAML.load_file(@options.fn_map)

				if map["typemaps"]
					@options.typemap = map["typemaps"]
				end

				if map["defaultmaps"]
					@options.defaultmap = map["defaultmaps"]
				end

			end

		end

		# DROP INDEXなDDLを吐く
		#
		# io::
		#  出力先
		def	drop_index(io)
			self.treat_index(io, :drop)
		end

		# CREATE INDEXなDDLを吐く
		#
		# io::
		#  出力先
		def	create_index(io)
			self.treat_index(io, :create)
		end

		# CREATE/DROP INDEXを吐く
		# 処理が似てるのでDROPも兼ねる。
		#
		# io::
		#  出力先
		# need::
		#  処理モード
		#    :create
		#    :drop
		def	treat_index(io, need)
			targets = self.enum_entities(@root, @options)

			targets.each { |e|

				# refs #8 インデックス番号＝アノテーションで付けたインデックス番号
				#   -> @ix 1 なら「1」
				# だったが、ERインデックスを同列に処理するために、@jude_idも
				# 入りうることに変更した。
				#
				# indices = {
				# 	インデックス番号 => {
				#     type => "" | :unique
				#     columns => [
				#       列名,
				#       列名, ...
				#     ]
				#   }
				# }
				indices = {}
				add_column = Proc.new { |id,type,colname,index_name|
					index = indices[id]
					if index == nil
						# 初出
						index = {
							:type => type,
							:columns => [],
							# refs #8 ERインデックス用
							:name => index_name,
						}
						indices[id] = index
					end
					
					index[:columns].push(colname)
				}

				# 属性を列挙し、インデックス付与のアノテーションをチェックする
				enum_attributes(e).each { |a|
					self.find_annotations(a, "@key='@ux'").each { |ux|
						id = ux.child.to_s
						add_column.call(id, :unique, self.get_name(a), nil)
					}
					self.find_annotations(a, "@key='@ix'").each { |ix|
						id = ix.child.to_s
						add_column.call(id, "", self.get_name(a), nil)
					}
				}

				# refs #8 ERインデックス
				e.find("./indices/er_index").each { |erindex|
					erindex.find("./index_attributes/index_attribute").each {|index_attr|
						a = @root.find("//er_attribute[@jude_id='#{index_attr["ref"]}']").first
						type = erindex["is_unique"]=="true" ? :unique : ""
						add_column.call(erindex["jude_id"], type, self.get_name(a), self.get_name(erindex))
					}
				}


				if indices.size > 0
					io.puts ""
					io.puts "-- #{self.get_fullname(e)}"
					# jrubyとCRubyで順番が異なる場合があったのでソートすることに
					indices.keys.sort.each { |key|
						index_info = indices[key]
						# refs #8 ERインデックスは名前を持ってる
						# 別名を入れる場所はないので、最初から物理名相当を入れないとダメ
						if index_info[:name]
							index_name = index_info[:name]
						else
							prefix = "ix"
							if index_info[:type] == :unique
								prefix = "ux"
							end
							index_name = "#{prefix}#{self.get_name(e)}_#{key}"
						end

						if need == :create
							io.puts @sql_dialect.create_index(self.get_name(e), index_info[:type], index_name, index_info[:columns])
						elsif need == :drop
							io.puts @sql_dialect.drop_index(self.get_name(e), index_name)
						end
					}
				end
			}
		end

		# DROP TABLEなDDLを吐く
		#
		# io::
		#  出力先
		def	drop_table(io)
			targets = self.enum_entities(@root, @options)

			targets.each { |e|
				io.puts @sql_dialect.drop_table(self.get_name(e))
			}
		end

		# ALTER TABLE add foreign keyなDDLを吐く
		#
		# io::
		#  出力先
		def	add_fk(io)
			self.treat_fk(io, :add)
		end

		# ALTER TABLE DROP CONSTRAINT fkなDDLを吐く
		#
		# io::
		#  出力先
		def	drop_fk(io)
			self.treat_fk(io, :drop)
		end

		# FK周辺
		#
		# TODO: 現在のところ、FK用のリレーションはERモデルにしかない、という前提
		#
		# クラス図でも関連から導く道はあるが、列をどう明示したものか。
		# 一定のルールで決めウチというセンもなくはないが・・
		#
		# io::
		#  出力先
		# mode::
		#  処理モード
		#    :add ALTER TABLE aaa ADD CONSTRAINT ccc FOREIGN KEY
		#    :drop ALTER TABLE aaa DROP CONSTRAINT ccc
		def	treat_fk(io, mode)

			# リレーションから、配下の外部キーにあたる属性（の名前）を列挙して返す
			enum_fks = Proc.new { |rel|
				rel.find("./foreign_keys/foreign_key").map { |fk|
					ref_key = fk["ref_key"].to_s
					a = @root.find("//er_attribute[@jude_id='#{ref_key}']").first
					self.get_name(a)
				}
			}

			# エンティティを順番に走査し、親へのリレーションをFK制約にする
			#
			# 親が必須でない場合skip
			# 依存型か非依存型かで判断する道もあるが、サロゲートキーを導入する場合、
			# JUDEでは非依存型でリレーションを付けざるを得ないため。
			targets = self.enum_entities(@root, @options)
			targets.each { |e|
				e.find("./parent_relationships/relationship").each_with_index { |rel,index|
					if index == 0
						io.puts ""
						io.puts "-- #{self.get_fullname(e)}"
					end

					if rel["is_parent_required"] != "true"
						next
					end

					fks_child = enum_fks.call(rel)

					child_fullname = rel["child"]
					ref_child = rel["ref_child"]
					parent_fullname = rel["parent"]
					ref_parent = rel["ref_parent"]
					parent = @root.find("//entity[@jude_id='#{ref_parent}']").first
					constraint_name = "fk_#{self.get_name(e)}_#{self.get_name(parent)}_#{index}"

					rel_parent = parent.find("./children_relationships/relationship[@ref_parent='#{ref_parent}' and @ref_child='#{ref_child}']").first
					fks_parent = enum_fks.call(rel_parent)

					if mode == :add
						io.puts @sql_dialect.add_fk(self.get_name(e), fks_child, self.get_name(parent), fks_parent, constraint_name)
					else
						io.puts @sql_dialect.drop_fk(self.get_name(e), constraint_name)
					end
				}
			}
		end

		# テーブル属性一覧に貼り付けるcsvを吐く
		#
		# io::
		#  出力先
		def	table_spec(io)
			targets = self.enum_entities(@root, @options)
			column_types = self.get_columntypes

			targets.each { |e|
				# テーブルの始まり
				cms = []
				# コメントにコメントがぶら下がる場合がある
				cms = self.get_desc(e, @options).uniq
				self.esc_out [ "#{self.get_name(e)}", "", "", "", cms.join("\n\n") ], io

				# 各列
				self.enum_attributes(e).each { |a|
					# 列型
					type, column_type = self.decide_type(a, column_types)

					# 説明
					setsumei = []
					# 列型についた説明
					if column_type
						setsumei = self.get_desc(column_type, @options).uniq
					end
					# 列についた説明
					setsumei += self.get_desc(a, @options).uniq

					domain_text = type
					if column_type
						domain_text = self.get_name(column_type)
					end

					self.esc_out([ "", "#{self.get_name(a)}", domain_text, type, setsumei.join("\n\n") ], io)
				}

			}
		end

		# テーブル一覧
		#
		# io:: 出力先IOオブジェクト
		def	table_list(io)
			targets = self.enum_entities(@root, @options)
			targets.each { |e|
				io.puts "#{self.get_name(e)}"
			}
		end

		# 属性の型を返す
		# クラス図由来:
		#  o 属性のtype
		# ER図由来:
		#  o 属性のdata_type＋長さ
		#  o ドメインのdatatype_name＋長さ
		#
		# 最後にtypemapで置換
		#
		# a::
		#   {属性|ER属性}を指すXML要素
		# column_types::
		#  型名をキーとするデータ型へのハッシュ
		def decide_type(a, column_types)
			# クラス図由来の型
			type = a["type"].to_s.strip
			column_type = column_types[type]

			# クラス図由来の型が空文字＝ERエンティティ
			if type == ""
				# 5.3.0からドメイン指定の属性の場合に、
				# ドメインのデータ型が取得されるようになった。
				# このため、属性のデータタイプなのかドメイン由来か判断できない。
				# ので、ドメインの判定を先に持ってくる
				ref_domain = a["ref_domain"]
				if ref_domain.to_s != ""
					domain = @root.find("//domain[@jude_id='#{ref_domain}']").first
					if domain
						type = self.add_length_precision(domain, domain["datatype_name"]) 
						column_type = domain
					end
				else
					# ドメインがないので属性のデータ型名を使う
					type = a["data_type"]
					type = self.add_length_precision(a, type)
					column_type = column_types[type]
					#column_type = nil
				end
			end

			if @options.typemap[type]
				# タイプマップで置換する場合がある
				type = @options.typemap[type]
			end

			[type, column_type]
		end

		# 指定された要素が長さの情報を持つ場合に、SQL型ように文字列整形する
		# aがドメインを指す場合に、ドメインに長さの情報があれば
		#   ドメインのデータ型(長さ)
		# となるように置換する
		#
		# a::
		#   型情報を指すXML要素
		# type::
		#   型名を表す文字列
		def	add_length_precision(a, type)
			len = a["length_precision"]
			if len && len != ""
				type="#{type}(#{len})"
			end

			type
		end

		# 属性の初期値
		# クラス由来：
		#   o 属性の初期値
		# ER図由来：
		#   o 属性の初期値
		#   o ドメインの初期値
		# 最後に初期値マップで置換
		#
		def	decide_initial_value(a , column_type)
			initial_val = a["initial_value"]
			if initial_val.to_s == ""
				initial_val = a["default_value"]

				# 5.3.0 属性にドメインを指定すると初期値を編集しても保存されない問題がある
				# ので、@defaultアノテーションも参照することに
				if initial_val.to_s == ""
					el_default = self.find_annotations(a, "@key='@default'").first
					if el_default
						initial_val = el_default.child.to_s
					end
				end
			end

			if column_type && initial_val.to_s == ""
				initial_val = column_type["default_value"]

				# 5.3.0 ドメインの初期値がとれない問題がある
				# ので、ドメインの@defaultアノテーションも参照することにした。
				if initial_val.to_s == ""
					el_default = self.find_annotations(column_type, "@key='@default'").first
					if el_default
						initial_val = el_default.child.to_s
					end
				end
			end


			if @options.defaultmap[initial_val]
				initial_val = @options.defaultmap[initial_val]
			end
			initial_val = initial_val.to_s.strip
		end

		# CREATE TABLEなDDLを吐く
		#
		# io::
		#  出力先
		def	create_table(io)
			targets = self.enum_entities(@root, @options)

			column_types = self.get_columntypes

			# 処理対象要素を順番に
			# -- テーブル名
			# -- コメント
			# craete table ****
			# (
			#   列名 型 付加情報
			#   PRIMARY KEY (xx)
			# )
			# てな感じ
			targets.each { |e|
				io.puts ""
				# テーブル名。日本語
				io.puts "-- #{e["fullname"].to_s}"
				io.puts "-- "
				self.get_desc(e, @options).each { |d|
					d.each { |line|
						io.puts "-- #{line}"
					}
				}
				io.puts "CREATE TABLE #{self.get_name(e)} ("

				first_attr = true
				cols_pk = []
				self.enum_attributes(e).each { |a|
					# 列単位の制約
					col_const = []

					if !first_attr
						io.puts ","
						io.puts ""
					end
	
					# 列型
					type, column_type = self.decide_type(a, column_types)

					# 列名。日本語
					io.puts "\t-- #{a["name"].to_s}"

					# 列型についた説明
					if column_type
						column_type.find("./definition").each { |d|
							d.child.to_s.each { |line|
								io.puts "\t-- #{line}"
							}
						}
					end
					# 列についた説明
					a.find("./definition").each { |d|
						d.child.to_s.each { |line|
							io.puts "\t-- #{line}"
						}
					}

					# 初期値
					initial_val = self.decide_initial_value(a, column_type)
					if initial_val != ""
						initial_val = "DEFAULT #{initial_val}"
					end

					# auto increment(mysql)
					if self.find_annotations(a, "@key='@ai'").first
						col_const.push("AUTO_INCREMENT")
					end

					if self.is_pk(a)
						# @pk
						cols_pk.push(self.get_name(a))
					end

					# NOT NULL
					if self.is_not_null(a, column_type)
						col_const.push("NOT NULL")
					end

					# @uniq
					if self.is_uniq(a)
						col_const.push("UNIQUE")
					end

					# VARCHAR/NVARCHAR/CHAR特別扱い
					# クラス図で書いてたころの名残。長さを指定する余地
					if type =~ /^((?:VARCHAR|NVARCHAR|CHAR))([0-9]+)/i
						type = "#{$1}(#{$2})"
					end

					io.write "\t#{self.get_name(a)} #{type} #{initial_val} #{col_const.join(" ")}"
					first_attr = false
				}

				io.puts ""
				# テーブル単位の付加情報
				io.puts ""
				
				# @pk
				if cols_pk.size > 0 
					io.puts "\t, primary key( #{cols_pk.join(',')} )"
				end

				io.puts ");"
			}
		end

		# 属性がUNIQUE制約を付与されているかどうか
		#
		# a:: 属性を指すXML要素
		def	is_uniq(a)
			if self.find_annotations(a, "@key='@uniq'").first
				return	true
			end
			false
		end

		# 属性がPK制約を付与されているかどうか
		#
		# a:: 属性を指すXML要素
		def	is_pk(a)
			if self.find_annotations(a, "@key='@pk'").first ||
				a["is_primary_key"].to_s == "true"
				return	true
			end
			false
		end

		# 属性がNOT NULL制約を付与されているかどうか
		#
		# クラス由来：
		#   o 属性に@nnアノテーションがあるかどうか
		#   o 属性の型を示すクラスに@nnアノテーションがあるかどうか
		# ER図由来：
		#   o 属性自身にNOT NULL指定があるかどうか
		#   o ドメインにNOT NULL指定があるかどうか
		#
		# a:: 
		#  属性を指すXML要素
		# column_type::
		#  属性の型を示すクラスのXML要素（ドメインの場合もある）
		def	is_not_null(a, column_type)
			if self.find_annotations(a, "@key='@nn'").first ||
				(column_type && self.find_annotations(column_type, "@key='@nn'").first) ||
				a["is_not_null"].to_s == "true" ||
				(column_type && column_type["is_not_null"].to_s == "true")
					return	true
			end
			false
		end

		# 列型を表すClassを拾う
		# Classのフル名をキーとし、対象要素を指すHash
		#
		# ER図でいうとドメインにあたるもの
		def	get_columntypes
			ret = {}
			@root.find("//class[./stereotypes/stereotype[text()='columntype']]").each {|e|
				fullname = e["fullname"]
				ret[fullname] = e
			}

			ret
		end

		def	self.main(argv)
			# オプションのデフォルト値
			options = OpenStruct.new
			options.encode = "utf-8"
			options.fullname = nil
			options.since = nil
			options.fn_out = nil
			options.fn_map = nil
			options.use_alias1 = nil
			options.use_physical_name = nil
			options.need_add_fk = false
			options.need_drop_fk = false
			options.need_create_table = false
			options.need_create_index = false
			options.need_drop_table = false
			options.need_drop_index = false
			options.definition_only = nil

			# オプション
			OptionParser.new { |opt|
				opt.banner = "usage: #{File.basename($0)} output-type [options] [in-filename]"
				opt.separator " o use STDIN instead of file if filename was ommited."
				opt.separator " "
				opt.separator "Output-types:"

				opt.on("--create-table", "specify to output create table") do |v|
					options.need_create_table = true
				end
				opt.on("--create-index", "specify to output create index") do |v|
					options.need_create_index = true
				end
				opt.on("--drop-table", "specify to output drop table") do |v|
					options.need_drop_table = true
				end
				opt.on("--drop-index", "specify to output drop index") do |v|
					options.need_drop_index = true
				end
				opt.on("--table-spec", "specify to output table spec") do |v|
					options.need_table_spec = true
				end
				opt.on("--table-list", "list of table name") do |v|
					options.need_table_list = true
				end
				opt.on("--add-fk", "alter table add foreign key") do |v|
					options.need_add_fk = true
				end
				opt.on("--drop-fk", "alter table drop fk") do |v|
					options.need_drop_fk = true
				end

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

				opt.on("--use-alias1", "use alias1 to identifiers") do |v|
					options.use_alias1 = true
				end

				opt.on("--use-physical-name", "use physical-name to identifiers") do |v|
					options.use_physical_name = true
				end

				opt.on("-m", "--map=mapping.yml", "specify mapping .yml") do |v|
					options.fn_map = v
				end

				begin
					opt.parse!(argv)

					# 出力タイプはいずれか1つ以上指定必須
					if !options.need_table_spec and !options.need_create_table and
						!options.need_drop_table and !options.need_create_index and
						!options.need_drop_index and !options.need_table_list and
						!options.need_add_fk and !options.need_drop_fk
						raise ArgumentError, "*** specify one of output-types."
					end
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
			if options.fn_out
				begin
					io_out = fp_out = File.new(options.fn_out, "w")
				rescue => ex
					raise "*** failed to open #{options.fn_out}: #{ex.message}"
				end
			else
				io_out = STDOUT
			end

			begin
				io_out.extend(TextConverter).from_to("utf-8", options.encode)

				sb = JudeUtil::SqlBuilder.new(doc.root, options)

				if options.need_table_list
					sb.table_list(io_out)
				end

				if options.need_table_spec
					sb.table_spec(io_out)
				end

				if options.need_drop_table
					sb.drop_table(io_out)
				end

				if options.need_create_table
					sb.create_table(io_out)
				end

				if options.need_drop_fk
					sb.drop_fk(io_out)
				end

				if options.need_add_fk
					sb.add_fk(io_out)
				end

				if options.need_drop_index
					sb.drop_index(io_out)
				end

				if options.need_create_index
					sb.create_index(io_out)
				end

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
	exit	JudeUtil::SqlBuilder::main(ARGV)
end


# vi: ts=2 sw=2

