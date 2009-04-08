# = ユーティリティメソッド
# 主にエクスポートしたxmlの情報取得・加工
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

def	is_jruby?
	defined?(JRUBY_VERSION)
end

require 'iconv'
require "xml_util"

module	JudeUtil
	Version='5.5.0.5'

	# エンティティを指す要素のリスト
	# 
	# つまりstereotype=entityなClassとentity
	# @since指定がある場合、オプション指定と比較して取捨選択
	#
	# root::
	#  走査を開始するXML要素
	# options::
	#  解析済み実行時オプション
	def	enum_entities(root, options)
		# Entityなclass
		# オプションで絞込み
		(self.select_target(root, "//class[./stereotypes/stereotype[text()='entity']]", options) + 
			self.select_target(root, "//entity", options)
		).find_all { |e|
			if self.enum_attributes(e).size == 0
				next false
			end
			true
		}
	end

	# 属性列挙
	#
	# ERモデルも対象に
	#
	# e::
	#   entityまたはclassを指すXML要素
	def	enum_attributes(e)
		e.find("./attributes/attribute").to_a +
			e.find("./primary_keys/er_attribute").to_a +
			e.find("./non_primary_keys/er_attribute").to_a
	end

	# ステレオタイプ列挙
	# ステレオタイプを表す文字列の配列を返す
	# ステレオタイプが存在しなければ空の配列
	#
	# e::
	#   IElementなJUDE要素を指すXML要素
	def	enum_stereotypes(e)
		e.find("./stereotypes/stereotype").to_a.map { |s| s.child.to_s }
	end

	# 非PKな属性
	#
	# e::
	#   entityまたはclassを指すXML要素
	def	enum_attributes_nonpk(e)
		e.find("./attributes/attribute").to_a.find_all{ |n|
			if self.find_annotations(n, "@key='@pk'").size > 0 
				next false
			end
			true
		} + e.find("./non_primary_keys/er_attribute").to_a
	end


	# テキストからコピペでExcelに貼り付けられるように値をクォートする
	# が、loose
	# 二重引用符は2つ重ねる。
	# 変換後文字列を返す
	# 
	# t::	変換元文字列
	def	make_excel_cell_value(t)
		t = t.split(/[\x0d\x0a]/).join("\n").gsub(/"/, '""')
		"\"#{t}\""
	end

	# 指定要素についた説明とコメントを連結して返す
	# 空文字除外
	#
	# e::	XML要素
	# sep::	連結の際、間に挟む文字列
	# desc_only:: 
	#   trueなら要素についたコメントを含めない
	#   falseなら要素についたコメントも含める
	def	make_desc(e, sep, desc_only)
		self.get_desc(e, desc_only).uniq.find_all{|d| d != ""}.join(sep)
	end

	# 指定要素についた説明とコメントを配列で返す
	# 各要素は前後の空白をstripされる
	#
	# JUDE-APIの仕様で、コメントがリンクする先は
	#   o コメントを付けた要素自体
	#   o コメントを付けた図が所属する要素（パッケージ、ユースケース、クラス等）
	# ということになっている。
	# なので、ユースケースの直下にコミュニケーション図を置き、ノートをつけると
	# 当該ユースケース付きのコメントとして取得されてしまう。
	# 要素についたコメントなのか、図が所属する要素に付いたコメントか
	# 区別できない
	#
	# e::	
	#   XML要素
	# desc_only:: 
	#   trueなら要素についたコメントを含めない
	#   falseなら要素についたコメントも含める
	def	get_desc(e, desc_only)
		# 説明
		desc = []
		e.find("./definition").each { |d|
			desc.push(d.child.to_s.strip)
		}

		if !desc_only
			# コメントにコメントがぶら下がっているケースがある
			e.find(".//comment").each { |c|
				# TODO: 図が所属する要素についたコメントを除外したい
				effective_annotated_count = 0
				c.find("./annotated_elements/annotated_element[@fullname!='']").each {|an|
					# 自要素以外に名前を持つ要素へのリンクが1つ以上あるノート
					# を自要素へのコメントとして妥当としておく。
					#  o モデル配下のクラス図中のリンクしないコメント
					#  o モデル配下のコミュニケーション図中のコメント
					# は排除できる
					target = e.doc.find("//*[@jude_id='#{an["ref"]}']").first
					if !target
						next
					end

					if target.equal?(e)
						next
					end

					effective_annotated_count = effective_annotated_count + 1
				}
				if effective_annotated_count == 0
					next
				end

				# libxml-rubyの場合、単純にchild.to_sしてしまうと、
				# 最初の子ノードが入れ子コメントだった場合に
				# XMLを文字列化したものを得てしまうので、
				# TEXTノードだけ厳選してto_sする
				n = c.child
				while n
					if n.text?
						desc.push(n.to_s.strip)
					end
					n = n.next
				end
			}
		end

		desc
	end

	# タグ付き値とアノテーションを同一視するためのサポートメソッド
	#
	# JUDEにタグ付き値がリリースされる以前に作ったデータを救うため。
	#
	# ./annotations/annotation[#{述部}]
	# ./tagged_values/tagged_value[#{述部}]
	# について存在した方を返す。
	# annotationsが優先される
	#
	# e::
	#   走査開始XML要素
	# pred::
	#   述部
	def	find_annotations(e, pred)
		ret = e.find("./annotations/annotation[#{pred}]")
		if ret.size > 0
			return	ret
		end

		ret = e.find("./tagged_values/tagged_value[#{pred}]")
		if ret.size > 0
			return	ret
		end

		[]
	end

	# XML文書の指定要素配下で条件に合う要素群を返す
	# exprには、
	# "//class[./stereotypes/stereotype[text()='boundary']]"
	# のような検索式を指定する"
	#
	# また、オプションで@sinceアノテーションへの限定がある場合は、
	# さらに限定した結果を返す。
	#
	# @return	該当した要素の配列
	#
	# root::	
	#  走査を開始するXML要素
	# expr::	
	#   検索式
	# options::	
	#   追加の限定条件
	def	select_target(root, expr, options)
		targets = root.find(expr).find_all { |e|
		
			fullname = e["fullname"]
			an_since = self.find_annotations(e, "@key='@since'").first
			# 指定ナシの場合"0.0.0"として扱う
			since = "0.0.0"
			if an_since 
				since = an_since.child.to_s
			end
	
			treat = false
			if options.fullname == nil || fullname =~ /#{options.fullname}/
				if options.since == nil || since =~ /#{options.since}/ 
					treat = true
				end
			end

			treat
		}
	
		return	targets
	end

	# 指定された配列の各要素をExcelエスケープして、連結してputs
	#
	# cols::
	#  列の値の配列
	# io::
	#  出力先IOオブジェクト
	def	esc_out(cols, io)
		out = []
		cols.each { |c|
			out.push(self.make_excel_cell_value(c.to_s))
		}

		io.puts out.join("\t")
	end


	# 指定要素のfullname属性を返す
	# 動作オプションを見てfull_alias1を返す
	#
	# e::
	#   対象XML要素。INamedElementに対応する
	# force::
	#   真の場合、動作オプションに関係なくオリジナルのfullnameを返す
	def	get_fullname(e, force = false)
		ret = ""
		if !force
			if @options.use_physical_name
				ret = e["physical_name"].to_s
			end
			if ret == "" and @options.use_alias1
				ret = e["full_alias1"].to_s
			end
		end

		if force || ret == ""
			ret = e["fullname"].to_s
		end
		ret
	end

	# 指定要素の親を探す
	# ここでの親とは、XML要素での親ではなく、
	# 指定要素の親を順に辿り、最初にfull名を持つXML要素。
	# 最終的にroot要素に到達した場合は、root要素を返す
	#
	# e::
	#   対象XML要素
	def	get_parent(e)
		root = e.doc.root
		while e = e.parent
			if e.equal?(root) || e["fullname"].to_s != ""
				return	e
			end
		end
		nil
	end

	# 指定要素の名前空間（＝親のfull名）を返す
	# 親のfull名が空文字なら"::"を返す
	#
	# e::
	#   対象XML要素。INamedElementに対応する
	# force::
	#   真の場合、動作オプションに関係なくオリジナルのfullnameを返す
	def	get_namespace(e, force = false)
		e = self.get_parent(e)
		if e.equal?(e.doc.root)
			return	"::"
		end

		ret = self.get_fullname(e, force).to_s
		ret
	end


	# 指定要素のname属性を返す
	# 動作オプションを見て物理名またはalias1を返す
	#
	# e::
	#   対象XML要素。INamedElementに対応する
	def	get_name(e)
		ret = ""
		if @options.use_physical_name
			ret = e["physical_name"].to_s
		end

		if ret == "" && @options.use_alias1
			ret = e["alias1"].to_s
		end

		if ret == ""
			ret = e["name"].to_s
		end

		ret
	end

	# CRUD表から、どのモデルにどの操作が割りついているかを返す
	#
	# @ret = {
	#   :model2crud => {
	#     "モデル名" => {
	#       'C' => 1,
	#       'R' => 1,
	#       'U' => 1,
	#       'D' => 1,
	#       # もし、D指定がない場合は、Dキーなし。他の操作も同様。
	#     }
	#   },
	#   :usecase2crud => {
	#     "ユースケース名" => {
	#       'C' => 1,
	#       'R' => 1,
	#       'U' => 1,
	#       'D' => 1,
	#       :entities => {
	#         # 当該ユースケースに関して、
	#         # CRUDのいずれかが定義されているエンティティ群
	#         "モデル名1" => 1,
	#         "モデル名2" => 1,
	#         "モデル名3" => 1,
	#       }
	#   },
	# }
	#
	# root::
	#   走査開始するXML要素
	# options::
	#   動作オプション
	def	load_crud(root, options)
		models = {}
		model2uc = {}
		usecases = {}

		# 現状はMatrixDiagram=CRUDなので問題ないんだけど・・
		crud_diagrams = self.select_target(root, "//matrix_diagram", options)

		crud_diagrams.each { |d|
			# どの列がモデルを指すのか調べる
			# er_models = {
			#   列インデックス => "モデル名",
			# }
			er_models = {}
			d.find("./show_column_headers/header_cell").each_with_index {|h,index|
				# 何かしら親がいればモデル名とみなす
				parent = h["parent"]
				if parent.to_s != ""
					# refs #6 キーを名前からIDに変更
					model = h["ref_model"]
					er_models[index.to_s] = model
				end
			}

			### モデルごとにCRUD情報を取り出す

			# 先に空の入れ物を作る
			er_models.values.each { |v|
				if models[v] == nil
					models[v] = {}
					model2uc[v] = {}
				end
			}

			# 続いてユースケースに対するCRUDの情報
			# どの行がユースケースを指すのか調べる
			# crud_usecases = {
			#   行インデックス => "ユースケースfull名"
			# }
			crud_usecases = {}
			d.find("./show_row_headers/header_cell").each_with_index {|h,index|
				# 何かしら親がいればユースケースとみなす
				if h["parent"].to_s != ""
					# refs #6 キーを名前からIDに変更
					crud_usecases[index.to_s] = h["ref_model"]
				end
			}

			# ユースケースごとにCRUD情報を取り出す
			# 先に空の入れ物を作る
			crud_usecases.values.each { |v|
				if usecases[v] == nil
					usecases[v] = {
						:entities => {}
					}
				end
			}

			d.find("./cell_values/cell").each { |cv|
				val = cv.child.to_s
				crud_ops = val.split(//)
				row = cv["row"]
				col = cv["col"]
				usecase_id = crud_usecases[row]
				model_id = er_models[col]
				# ユースケースとモデルの交点で、
				# かつ何かしらの操作が定義されているセルだけ処理する
				if usecase_id == nil || model_id == nil || val == ""
					next
				end


				# あるユースケースに対して、
				# CRUDのいずれかの操作が定義されているモデル名を保存しておく
				usecases[usecase_id][:entities][model_id] = 1

				# モデル名からユースケースとその操作をひけるように保存
				rec = model2uc[model_id]
				if !rec
					rec = model2uc[model_id] = {}
				end
				rec[usecase_id] = {}

				crud_ops.each { |mark|
					usecases[usecase_id][mark] = 1
					models[model_id][mark] = 1
					rec[usecase_id][mark] = 1
				}
			}
		}
		#pp [ models ]
		#pp [ usecases ]

		return	{ 
			:model2usecase => model2uc, 
			:model2crud => models, 
			:usecase2crud => usecases,
		}
	end

	# エンコード変換して出力、なmodule
	# IOにexntendする
	module	TextConverter
		# from::
		#   変換元のエンコード名
		# to::
		#   変化先エンコード名
		def	from_to(from, to)
			if from != to 
				@iconv = Iconv.new(to, from)
			end
		end

		def	write(s)
			if @iconv
				s = @iconv.iconv(s)
			end

			super(s)
		end
	end

end

# vi: ts=2 sw=2 noexpandtab

