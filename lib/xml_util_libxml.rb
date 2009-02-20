# = XML操作系共通メソッド
# libxml-ruby用
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

begin
	require 'rubygems'
rescue LoadError
end

require 'libxml'

LibXML::XML::Document.class_eval do
	def	create_element(name)
		LibXML::XML::Node.new(name)
	end
	alias	:createElement :create_element

	# libxmlだとimportなくてもcopyすれば別docに接ぎ木できる
	# org.w3c.dom.Document互換
	def	import_node(el, deep)
		el.copy(deep)
	end
	alias	:importNode :import_node
end

LibXML::XML::Node.class_eval do
	def	element?
		self.node_type_name == "element"
	end
end

module	JudeUtil

	module	XML

		# 空のDocumentを生成して返す
		#
		def	new_document
			LibXML::XML::Document.new
		end

		# 指定されたファイルをopenしてXML文書を返す
		#
		# fn_in::
		#   ファイル名。nilの場合、stdinを適用
		def build_document(fn_in)
			if !fn_in
				xp = LibXML::XML::Parser.new
				xp.string = STDIN.read
				doc = xp.parse
			else
				# XML読み込み
				doc = LibXML::XML::Document.file(fn_in)
			end

			doc
		end

		# XML文書をストリームに書き出す
		#
		# doc::
		#   XML文書
		# st::
		#   IO
		# enc::
		#   出力エンコード
		# omit_xml_decl::
		#   XML文書宣言の省略。だけどlibxml-rubyのオプション見つからず。。
		#   文字列レベルで落とすか
		# pretty::
		#   フォーマット有無
		def	write_document(doc, st, enc = "utf-8", omit_xml_decl=false, pretty=false)

			# libxml-ruby 0.9.7, 0.9.8（知っている範囲で）
			# :encoding にLibXML::XML::Encodingで定義されている定数が要求される
			# エンコーディング名から定数を得るメソッドがあるようだが機能していないっぽい
			# ので、暫定的にエンコーディング名を
			#  ハイフンをアンダースコアに、
			#  小文字を大文字に
			# 置き換えたもので定数値を得ることに・・・
			encoding = nil
			name = enc.gsub(/-/, "_").upcase
			if LibXML::XML::Encoding.const_defined?(name)
				encoding = LibXML::XML::Encoding.const_get(name)
			end
			st.write doc.to_s(:indent => pretty, :encoding => encoding)
		end
	end
end

# vi: ts=2 sw=2 noexpandtab

