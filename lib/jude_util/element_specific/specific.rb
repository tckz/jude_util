
module	JudeUtil

	# Jude要素を処理するクラス、の基底
	#
	# 特別処理しないJude要素はこのクラスでまかなう。
	#
	# 最初にJUDE要素の種類に対応した処理クラスインスタンスを生成しておいて
	# 使いまわす考え
	class	JudeElement
		attr_accessor	:exporter

		# コンストラクタ
		# 特に個別処理を用意しないJUDE要素もあるので、
		# これら用のクラスを全部書かなくていいようにタグ名を指定できるように
		# している。
		#
		# exporter::
		#  Exporterのインスタンス
		# tag::
		#  XML要素生成時のタグ名
		def	initialize(tag = nil)
			@tag = tag
		end

		# JUDE要素の内容から判断してXMLタグが変わる場合があるので
		# 継承クラス側で上書き出来る余地を持たせた。
		#
		# ex. 属性。配下にassociationがある場合は「関連」扱い
		#
		# e::
		#   JUDE要素
		def	tag(e)
			return	@tag
		end

		# JUDE要素ごとの固有処理
		#
		# el::
		#  XML文書の親要素
		# e::
		#  JUDE要素
		# index::
		#  当該JUDE要素が呼び出し元の親要素からみて何番目の子要素か、を表す整数
		def	doit(el, e, index)
		end

		def	make_fullname(e)
			@exporter.make_fullname(@exporter.root, e)
		end

		def	traverse_into(el, e)
			@exporter.traverse_into(el, e)
		end

		def	add_name_attr(e, el)
			@exporter.add_name_attr(@exporter.root, e, el)
		end

		def	process_childs(name , el, e, list)
			@exporter.process_childs(name, el, e, list)
		end

		# 実体となるJUDE要素は別に存在し、同要素へのリンクだけを列挙する
		# IElementについている（JUDEの）idをポインタにする
		#
		# el::
		#   ぶら下げる先となるXML要素
		# name::
		#   XML要素名
		#   複数性が+"s"決めウチなのがアレ
		# vals::
		#   リンク先JUDE要素の配列
		def	enum_link(el, name, vals)
			if vals.size > 0 
				el_vals = el.doc.createElement(name + "s")
				vals.each { |v|
					el_val = el.doc.createElement(name)
					el_val["ref"] = v.getId
					el_vals << el_val
				}
				el << el_vals
			end
		end

		# refs #7 5.4から操作と属性に移動した
		def	set_visibility(e, el)
			# 可視性
			visibility = nil
			if e.isPackageVisibility
				visibility = "package"
			elsif e.isPrivateVisibility
				visibility = "private"
			elsif e.isProtectedVisibility
				visibility = "protected"
			elsif e.isPublicVisibility
				visibility = "public"
			end
			if visibility
				el["visibility"] = visibility
			end

		end
	end

	module	ElementSpecific
		# 要素固有処理クラスをload
 		mod_path = File.dirname(File.expand_path(__FILE__))
		Dir.foreach(mod_path) { |ent|
			myname = File.basename(__FILE__)
			if ent != myname && ent =~ /\.rb$/
				fullpath = File.expand_path(ent, mod_path)
				require fullpath
			end
		}
	end

end

# vi: ts=2 sw=2

