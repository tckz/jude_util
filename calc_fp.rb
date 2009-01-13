#!/usr/bin/ruby

# = calc_fp.rb: calc FP from usecases(TF) and entities(DF) and CRUD diagrams.
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

require 'optparse'
require 'ostruct'
require 'pp'

$:.unshift(File.dirname(__FILE__))
require "lib/jude_util"

module	JudeUtil

	# トランザクショナルファンクション周辺
	module	CalcFP_TF
		include	JudeUtil

		# トランザクショナルファンクションのFP計算
		# TF=ユースケース、とみなす
		#
		# usecase2crud::
		#  ユースケース名をキーとした、当該ユースケースのCRUDおよび関連するエンティティ名配列へのハッシュ
		def calc_tf(root, options, usecase2crud)
			function_points = []

			#pp usecase2crud
			usecases = self.select_target(root, "//usecase", options).find_all { |e|
				!(self.find_annotations(e, "@key='@noest'").size > 0)
			}

			parent_pkgs = {}

			usecases.each { |uc|
				# refs #6 名前による参照からIDによる参照へ
				uc_id = uc["jude_id"]
				uc_fullname = self.get_fullname(uc)
				uc_namespace = self.get_namespace(uc)
				tf_type = self.tf_type(uc, usecase2crud)

				if uc_namespace != "" && !parent_pkgs[uc_namespace]
					pkg = self.get_parent(uc)
					if !@options.wo_pkg
						function_points.push({
							:fp_type => "TF", 
							:fullname => uc_namespace,
							:namespace => uc_namespace,
							:fp => "", 
							:fp_gai => "", 
							:option => [ "", "", "", "", "", "", self.make_desc(pkg, "\n--\n", true), ],
						})
					end
					parent_pkgs[uc_namespace] = pkg
				end

				sum_det = 0

				# ユースケースにぶら下がるFP見積用シーケンス図を探す
				uc.find("./sequence_diagram[starts-with(@name,'FP-')]").each { |sq|
					sum_det = sum_det + self.calc_det(root, sq)
				}

				# FTRはユースケースに関連するエンティティの数、
				# すなわちCRUDの指定が1つでもあるエンティティの数とみなす
				ftr = 0
				if usecase2crud[uc_id]
					ftr = usecase2crud[uc_id][:entities].size
				end

				# 複雑度の定義がDET>=1しかないので。
				if sum_det == 0 
					sum_det = 1
				end

				# EI/EO/EQ & DET & FTRから複雑度
				complex = self.tf_complex(tf_type, sum_det, ftr)
				# EI/EO/EQ & 複雑度からFP
				fp = self.tf_complex2fp(complex, tf_type)
				fp_gai = self.tf_complex2fp(:average, tf_type)

				# 概要欄
				# ユースケース記述の概要＋「定義」＋「コメント」
				descs = []
				ret = uc.find("./tagged_values/tagged_value[@key='uc.description.summary']")
				if ret.size > 0 
					descs.push(ret.first.child.to_s)
				end

				descs.push(self.make_desc(uc, "\n--\n", options.definition_only))
				desc = descs.join("\n\n")

				function_points.push({
					:fp_type => "TF", 
					:fullname => uc_fullname,
					:namespace => uc_namespace,
					:fp => fp, 
					:fp_gai => fp_gai, 
					:option => [ complex, sum_det, "", "", ftr, tf_type, desc ],
				})
			}

			#pp function_points
			function_points
		end

		# ユースケースにぶら下がるシーケンス図からDETに
		def	calc_det(root, sq)

			sum_det = 0

			# 図中のアクター発のメッセージを操作のトリガとして集計する
			sq.find("./messages/message").each { |m|
				# メッセージのsourceのライフラインのbaseがactorか？
				lifeline = sq.find("./lifelines/lifeline[@jude_id='#{m["ref_source"]}']").first
				if !root.find("//class[@jude_id='#{lifeline["ref_base"]}' and ./stereotypes/stereotype='actor']").first
					next
				end

				# メッセージ1つをトリガ一個とみなす
				det = 1

				# メッセージの引数の数をDETに加算
				ref_operation = m["ref_operation"].to_s
				argument = m["argument"].to_s
				if ref_operation != ""
					# 操作として明示されている場合
					# 配下のparameterを数える
					op = root.find("//operation[@jude_id='#{ref_operation}']").first
					if op
						det = det + op.find("./parameters/parameter").size

						# 操作の返り値の数を加算
						# 返り値は1つしか指定できない。ので、classが指定された場合は
						# その配下の属性数を加算する
						rv = root.find("//*[@jude_id='#{op["ref_return_type"]}']").first
						if rv
							det = det + rv.find("./attributes/attribute").size
						end
					end
				elsif argument != ""
					# 操作として明示されていない場合は、文字列表現を無理ぐり区切って
					# パラメータ数とする
					det = det + argument.split(/\s*,\s*/).size
				end


				sum_det = sum_det + det
			}

			sum_det
		end

		# トランザクショナルファンクションの複雑度と種別からFPを返す
		def	tf_complex2fp(complex, tf_type)
			fp = {
				:low => 3,
				:average => 4,
				:high => 6,
			}
			if tf_type == :EI
				fp = {
					:low => 3,
					:average => 4,
					:high => 6,
				}
			elsif tf_type == :EO
				fp = {
					:low => 4,
					:average => 5,
					:high => 7,
				}
			end

			return	fp[complex]
		end

		# トランザクショナルファンクションの複雑度を返す
		def	tf_complex(tf_type, det, ftr)
			if tf_type == :EI
				# EIの場合
				if ftr >= 0 && ftr <= 1
					if det >= 1 && det <= 4
						return	:low
					elsif det >= 5 && det <= 15
						return	:low
					else
						return	:average
					end
				elsif ftr == 2
					if det >= 1 && det <= 4
						return	:low
					elsif det >= 5 && det <= 15
						return	:average
					else
						return	:high
					end
				else
					if det >= 1 && det <= 4
						return	:average
					elsif det >= 5 && det <= 15
						return	:high
					else
						return	:high
					end
				end
			else
				# EO/EQの場合
				if ftr >= 0 && ftr <= 1
					if det >= 1 && det <= 5
						return	:low
					elsif det >= 6 && det <= 19
						return	:low
					else
						return	:average
					end
				elsif ftr >= 2 && ftr <= 3
					if det >= 1 && det <= 5
						return	:low
					elsif det >= 6 && det <= 19
						return	:average
					else
						return	:hight
					end
				else
					if det >= 1 && det <= 5
						return	:average
					elsif det >= 6 && det <= 19
						return	:high
					else
						return	:high
					end
				end
			end
		end

		# ユースケースがEI/EO/EQのいずれにあたるかを判断
		# 
		# @tfアノテーションで明示されている場合はこれを適用
		#
		# 明示がなければ、CRUD操作から決めウチ
		# 「CUD」のいずれかがあれば、EI扱い
		# 「R」のみならEO扱い
		#
		# データの加工が何もないケースは少なかろう、と考え、
		# EQよりもEOをデフォルトとした
		def	tf_type(uc, usecase2crud)
			el_an = self.find_annotations(uc, "@key='@tf'").first
			if el_an
				v = el_an.child.to_s.strip
				if v =~ /ei/i
					return	:EI
				elsif v =~ /eo/i
					return	:EO
				else
					return	:EQ
				end
			end

			# refs #6 名前による参照からIDによる参照へ
			crud = usecase2crud[uc["jude_id"]]
			if crud
				if crud["C"] || crud["U"] || crud["D"]
					return	:EI
				elsif crud["R"]
					return	:EO
				end
			end

			return	:EQ
		end

	end

	# データファンクション周辺
	module	CalcFP_DF
		include	JudeUtil

		# データファンクションのFP計算
		# DF＝ステレオタイプがentityとなるクラス
		# オプション指定で変更可
		#
		# model2crud::
		#   モデル名をキーとしたCRUD設定値
		def	calc_df(root, options, model2crud)
			function_points = []

			# エンティティがない属性は対象外
			data_funcs = self.enum_entities(root, options).find_all { |e|
				!(self.find_annotations(e, "@key='@noest'").size > 0)
			}

			parent_pkgs = {}

			data_funcs.each { |df| 
				# refs #6 名前による参照からIDによる参照へ
				model_id = df["jude_id"]
				# データファンクションのフル名
				df_fullname = self.get_fullname(df)
				df_namespace = self.get_namespace(df)

				if df_namespace != "" && !parent_pkgs[df_namespace]
					pkg = self.get_parent(df)
					if !@options.wo_pkg
						function_points.push({
							:fp_type => "DF", 
							:namespace => df_namespace,
							:fullname => df_namespace,
							:fp => "", 
							:fp_gai => "", 
							:option => [ "", "", "", "", "", "", self.make_desc(pkg, "\n--\n", true), ],
						})
					end
					parent_pkgs[df_namespace] = pkg
				end

				# DET計数
				# 非pk属性の数
				# でも、
				# Identifierじゃない設計だとPKにもDETとして意味ある属性が含まれる
				det = self.enum_attributes_nonpk(df).size
				# 保険というか、PKしかないエンティティの手当て
				if det == 0 
					det = 1
				end

				# RET計数
				# @retアノテーションの数
				# 未付加のものはRET=1扱い
				rets = self.find_annotations(df, "@key='@ret'")
				ret = 1
				if rets.size > 0 
					ret = rets.size
				end


				# RET & DETから複雑度
				complex = self.df_complex(ret, det)

				# EIF/ILF判別
				file_type = self.df_file_type(model2crud, model_id)

				# FP算出
				fp = self.df_complex2fp(complex, file_type)
				fp_gai = self.df_complex2fp(:low, file_type)

				# entityの説明とコメントを結合したもの
				desc = self.make_desc(df, "\n--\n", options.definition_only)
				
				function_points.push({
					:fp_type => "DF", 
					:namespace => df_namespace,
					:fullname => df_fullname,
					:fp => fp, 
					:fp_gai => fp_gai, 
					:option => [ complex, det, ret, file_type, nil, nil, desc ],
				})
			}

			function_points
		end

		# RETとDETからデータファンクションの複雑度を返す
		def	df_complex(ret, det)
			if ret == 1
				if det >= 1 && det <= 19
					return	:low
				elsif det >= 20 && det <= 50
					return	:low
				else
					return	:average
				end
			elsif ret >= 2 && ret <= 5
				if det >= 1 && det <= 19
					return	:low
				elsif det >= 20 && det <= 50
					return	:average
				else
					return	:high
				end
			else
				if det >= 1 && det <= 19
					return	:average
				elsif det >= 20 && det <= 50
					return	:high
				else
					return	:high
				end
			end
		end


		# データファンクションの複雑度とファイルタイプからFPを返す
		def	df_complex2fp(complex, file_type)
			fp = {
				:low => 5,
				:average => 7,
				:high => 10,
			}
			if file_type == :ILF
				fp = {
					:low => 7,
					:average => 10,
					:high => 15,
				}
			end

			return	fp[complex]
		end

		# データファンクションをEIFかILFか判断する
		# CRUDのうちCUDのいずれかが存在する場合はILFとみなす。
		# それ以外（Rのみ）はEIF
		def	df_file_type(model2crud, model_name)
			cruds = model2crud[model_name]
			if cruds
				if cruds["C"] || cruds["U"] || cruds["D"]
					return	:ILF
				end
			end

			return	:EIF
		end
	end

	class	CalcFP
		include	JudeUtil
		include	CalcFP_TF
		include	CalcFP_DF

		def	initialize(root, options)
			@root = root
			@options = options
		end

		# FP計算
		def	calc_fp
			# モデル/ユースケースとCRUDの対応をロード
			crud_info = self.load_crud(@root, @options)

			# データファンクション
			df_fp = self.calc_df(@root, @options, crud_info[:model2crud])
			# トランザクショナルファンクション
			tf_fp = self.calc_tf(@root, @options, crud_info[:usecase2crud])

			(df_fp + tf_fp)
		end

		# FP計算＋出力
		def	out_fp(io)
			self.calc_fp.each { |rec|
				self.esc_out([ rec[:fp_type], rec[:namespace], rec[:fullname], rec[:fp], rec[:fp_gai] ] + rec[:option], io)
			}
		end

		def	self.main(argv)
			options = OpenStruct.new
			options.encode = "utf-8"
			options.since = nil
			options.fn_out = nil
			options.use_alias1 = nil
			options.fullname = nil
			options.df_stereotype = "entity"
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

				opt.on("-d", "--df=STEREOTYPE", "stereotype for data function") do |v|
					options.df_stereotype = v
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

			doc = XML::build_document(fn_in)

			fp_out = nil
			begin
				if options.fn_out
					io_out = fp_out = File.new(options.fn_out, "w")
				else
					io_out = STDOUT
				end
				io_out.extend(TextConverter).from_to("utf-8", options.encode)

				calcfp = JudeUtil::CalcFP.new(doc.root, options)

				calcfp.out_fp(io_out)
			ensure
				if fp_out
					fp_out.close
				end
			end


			0
		end
	end
end



###
### main
###




if $0 == __FILE__
	include	JudeUtil
	include	JudeUtil::XML

	Version = JudeUtil::Version
	exit	JudeUtil::CalcFP::main(ARGV)
end

# vi: ts=2 sw=2

