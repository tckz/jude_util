#!/usr/bin/ruby

# = jude_export.rb: export .jude to xml
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

# JUDE要素固有処理クラス群
require	"lib/exporter/specific"

# JUDE-APIからincludeするmodule
module Jude
	include_package "com.change_vision.jude.api.inf.project"
	include_package "com.change_vision.jude.api.inf.model"
	include_package "com.change_vision.jude.api.inf.presentation"
end

module	JudeUtil

	# .judeファイルの内容をXML文書に吐き出すクラス
	class	Exporter

    include JudeAPIUtil
    include JudeUtil
    include JudeUtil::XML

		attr_accessor	:root

		# コンストラクタ
		#
		# root::
		#  JUDEプロジェクトのRoot。解析開始JUDE要素
		def	initialize(root)
			@root = root
			@treat = {
				:IMindMapDiagram => JudeElement.new('mindmap_diagram') ,
				:IDataFlowDiagram => JudeElement.new('dataflow_diagram') ,
				:IERDiagram => JudeElement.new('er_diagram' ) ,
				:IUseCaseDiagram => JudeElement.new('usecase_diagram') ,
				:IDiagram => JudeElement.new('diagram') ,
				:IUseCase => JudeElement.new('usecase') ,
				:IInteractionFragment => JudeElement.new('interaction_fragment') ,
				:IInteractionUse => JudeElement.new('interaction_use') ,
				:IERModel => JudeElement.new('er_model') ,
				:IModel => JudeElement.new('model') ,
				:ISubsystem => JudeElement.new('subsystem') ,
				:IPackage => JudeElement.new('package') ,
				:IDataStore => JudeElement.new('datastore') ,
				:IDataFlow => JudeElement.new('dataflow') ,
				:IExternalEntity => JudeElement.new('external_entity') ,
				nil => JudeElement.new('element') ,
			}

			# 固有処理インスタンス準備
			self.load_element_specific(@treat)

			# IElementのTaggedValue列挙においてskipしてもよいkey名
			@tagged_value_skip = {
				# Alias1は個別に対応しているからskip
				"jude.multi_language.alias1" => 1,
				# Hyperlinkは個別に対応しているのでskip
				"jude.hyperlink" => 1,
			}
		end

		# JudeUtil::ElementSpecific配下のJUDE要素処理クラスを列挙して、
		# それぞれインスタンスを作って保存する
		#
		# keyは、
		#   クラス名から/^Treat/を除き、
		#   先頭に"I"を前置
		#   な文字列をシンボルに変換
		# したもの
		# TreatHeaderCellなら、:IHeaderCell
		def load_element_specific(treat)
			mod = ElementSpecific
			mod.constants.each { |name|
				if name !~ /Treat(.*)$/
					# 名前が合わない
					next
				else
					key = "I#{$1}".intern
				end
				if !eval("#{mod.name}::#{name}.kind_of?(Class)")
					# クラスじゃない
					next
				end

				treat[key] = eval("#{mod.name}::#{name}.new")
			}
		end

		# 名前周辺の属性をXML要素に追加する
    # name, fullname, alias1, full_alias1
    #
		# root::
		#  JUDE要素のroot
		# e::
		#  JUDE要素
		# el::
		#  追加先のXML要素
		def	add_name_attr(root, e, el)
			if e.name != ""
				full = self.make_fullname(root, e)
				el["fullname"] = full
				el["name"] = e.name

				alias1 = self.make_alias1(e)
				if alias1.to_s != e.name
					el["alias1"] = alias1
					el["full_alias1"] = self.make_full_alias1(root, e)
				end
			end
		end
		
		# JUDEプロジェクトを指定してXML文書にエクスポート
		# 生成されたXML文書を返す
		def	export
			# 空のXML文書とroot要素を作って、
			doc = XML::new_document
			el_root = doc.createElement("jude")
			el_root["util_version"] = JudeUtil::Version
			el_root["jruby_version"] = JRUBY_VERSION
			doc.root = el_root

			# 降下する
			# refs #9 ルート直下の図が出てなかった・・
			self.process_childs(nil, el_root, @root, @root.diagrams)
			self.process_childs(nil, el_root, @root, @root.getOwnedElements)

			doc
		end
	
		# 文字列からアノテーション表記を抜き出して、アノテーション情報を
		# 付与対象エレメントに追加する
		#
		# el::
		#   アノテーション付与対象XML要素
		# text::
		#   文字列。コメントや定義の内容
		def	parse_annotation(el, text)
			ans = []
			text.each { |t| 
				t = t.strip
				if t =~ /(@[a-zA-Z0-9_]+):?\s*(.*)$/
					key = $1
					val = $2
					ans.push({ :key => key, :val => val })
				end
			}

			if ans.size == 0 
				return
			end

			el_ans = el.find('./annotations').first
			if el_ans == nil
				el_ans = el.doc.createElement("annotations")
				el << el_ans
			end
	
			ans.each { |h|
				el_an = el.doc.createElement("annotation")
				el_an["key"] = h[:key]
				el_an << h[:val].to_s
				el_ans << el_an
			}
		end


		# 降下
		#
		# parent::
		#  今回解析した結果をぶら下げる先となるXML要素
		# e::
		#  処理対象のJUDE要素
		# index::
		#  呼び出し元の親要素から見て何番目の子かをMatrixのヘッダに付与したかっただけ。
		def	traverse_into(parent, e, index = nil)

			if e == nil
				# 処理対象がない
				return
			end

			# 固有処理クラスを決定
			treat_specific = self.decide_element_specific(e)

			# XMLタグ名
			tag = treat_specific.tag(e)
	
			# 自要素を作成して親にぶら下げる
			myelement = parent.doc.createElement(tag)
			parent << myelement

			if e.java_kind_of? Jude::IElement
				myelement["jude_id"] = e.getId

				# タグ付き値
				tvs = []
				# 個別処理していて不要なタグ付き値をスキップする
				e.taggedValues.each { |tv| 
					if @tagged_value_skip[tv.key] == nil
						tvs.push tv
					end
				}
				self.process_childs("tagged_values", myelement, e, tvs)
	
				# ステレオタイプ
				if e.stereotypes.size > 0
					el_stereotypes = myelement.doc.createElement("stereotypes")
					myelement << el_stereotypes
					e.stereotypes.each { |s|
						el_s = myelement.doc.createElement("stereotype")
						el_s << s
						el_stereotypes << el_s
					}
				end
	
				# コメント
				# 別の図で内容が同じコメントをつける場合があるので
				# uniqueにする
				already_exists = {}
				comm = []
				e.comments.each { |c|
					t = c.body.strip
					if already_exists[t] == nil
						already_exists[t] = 1
						comm.push(c)
						self.parse_annotation(myelement, t)
					end
				}
	
				self.process_childs("comments", myelement, e, comm)
			end
	
			if e.java_kind_of? Jude::INamedElement

				# 名前がついてないものは、英語名もフル名もナシとする
				self.add_name_attr(@root, e, myelement)
	
				# 定義
				d = e.definition.strip
				if d != "" 
					el_d = myelement.doc.createElement("definition")
					el_d << d
					myelement << el_d
	
					self.parse_annotation(myelement, d)
				end
	
				# 図
				self.process_childs(nil, myelement, e, e.diagrams)
				# 依存先-依存
				self.process_childs("supplier_dependencies", myelement, e, e.supplierDependencies)
				# 依存元-依存
				self.process_childs("client_dependencies", myelement, e, e.clientDependencies)
			end

			# ハイパーリンク
			if e.java_kind_of? Jude::IHyperlinkOwner
				self.process_childs("hyperlinks", myelement, e, e.hyperlinks)
			end
	
			# クラス
			if e.java_kind_of? Jude::IClass
				# 属性
				self.process_childs("attributes", myelement, e, e.attributes)
				# 操作
				self.process_childs("operations", myelement, e, e.operations)
				# 汎化
				self.process_childs("generalizations", myelement, e, e.generalizations)
				# 特化
				self.process_childs("specializations", myelement, e, e.specializations)
				# 実現-自要素が実現してるケース
				self.process_childs("client_realizations", myelement, e, e.clientRealizations)
				# 実現-自要素が実現されるケース
				self.process_childs("supplier_realizations", myelement, e, e.supplierRealizations)
			end
	

			# パッケージ系の場合、所有する子要素に降下
			if e.java_kind_of? Jude::IPackage
				self.process_childs(nil, myelement, e, e.ownedElements)
			end

			# JUDE要素固有の処理
			# オブジェクトに@nodetailアノテーションが付いている場合は
			# 固有処理しない
			if !myelement.find("./annotations/annotation[@key='@nodetail']").first
				treat_specific.doit(myelement, e, index)
			end
		end


		# JUDE要素から、固有処理を返す
		# 
		# e::
		#  JUDE要素
		def	decide_element_specific(e)
			# TODO: JUDE-APIのimplementsが変わるとダメ、現状だけ見ればいける
			interface = e.java_class.interfaces.first.name
			key = interface.gsub!(/^.*\./, "").intern
			process = @treat[key]
			if !process
				process = @treat[nil]
			end

			process.exporter = self

			process
		end

		# 特別な処理がなくて同じように流せるパターン
		# 
		# childs_name::
		#  子要素の名前（タグ名）
		# el::
		#  
		# e::
		#  
		# childs::
		#  
		def process_childs(childs_name, el, e, childs)
			if childs.size > 0
				if childs_name == nil
					el_childs = el
				else
					el_childs = el.doc.createElement(childs_name)
					el << el_childs
				end

				childs.each_with_index { |child, i| 
					self.traverse_into(el_childs, child, i)
				}
			end
		end

		def	self.main(argv)

			ec = 1

			# オプションのデフォルト値
			options = OpenStruct.new
			options.encode = "utf-8"
			options.fn_out = nil

			fn_in = nil

			# オプション
			OptionParser.new { |opt|
				opt.banner = "usage: #{File.basename($0)} [options] in.jude"
				opt.separator ""
				opt.separator "Options:"
				opt.on("-e", "--encoding=ENCODING-NAME", "default: #{options.encode}") do |v|
					options.encode = v
				end

				opt.on("-o", "--out=OUTPUT-FILENAME", "if ommited apply STDOUT") do |v|
					options.fn_out = v
				end

				begin
					opt.parse!(argv)

					fn_in = argv[0]
					if ! fn_in
						raise ArgumentError, "*** specify .jude filename"
					end

				rescue ArgumentError,OptionParser::ParseError => e
					STDERR.puts opt.to_s
					STDERR.puts ""
					STDERR.puts "#{e.message}"
					return	ec
				end
			}

			pa = JudeAPIUtil::open_jude(fn_in, true)
			begin
				exporter = JudeUtil::Exporter.new(pa.project)
				doc = exporter.export
			ensure
				pa.close
			end

			# で、指定のエンコードで出力先に書き出す
			st = java.lang.System.out
			opened = nil
			begin
				if options.fn_out
					opened = st = java.io.FileOutputStream.new(options.fn_out)
				end
				JudeUtil::XML::write_document(doc, st, options.encode)

				ec = 0
			ensure
				if opened
					opened.close
				end
			end

			return	ec
		end
	end

end



if $0 == __FILE__
	include JudeUtil
	include JudeUtil::XML
	include JudeAPIUtil

	Version = JudeUtil::Version
	exit	JudeUtil::Exporter::main(ARGV)
end

# vi: ts=2 sw=2

