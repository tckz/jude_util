# = XML操作系共通メソッド
# JavaのDOM/XPath APIをlibxml-ruby風に使えるようにする
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

require 'java'

# org.w3c.dom.Documentにlibxml-ruby風I/F追加
JavaUtilities.extend_proxy('org.w3c.dom.Document') do
	def	root=(el)
		self.appendChild(el)
	end

	def	root
		self.documentElement
	end

	def	doc
		self
	end
end

JavaUtilities.extend_proxy('org.w3c.dom.NodeList') do
	def	to_a
		ret = []
		for i in 0..(self.length - 1)
			ret.push(self.item(i))
		end
		ret
	end
end

# org.w3c.dom.Nodeにlibxml-ruby風I/F追加
JavaUtilities.extend_proxy('org.w3c.dom.Node') do
	@@xpath = nil

	def	<<(el)
		if el.kind_of?(String)
			el = self.doc.createTextNode(el)
		end

		self.appendChild(el)
		self
	end

	def	doc
		self.getOwnerDocument
	end

	# libxml-rubyのLibXML::XML::Node.to_s風
	# XML宣言を外している
	def	to_s
		st = java.io.StringWriter.new
		write_document(self, st, "utf-8", true)
		st.to_s
	end

	def	name
		self.getNodeName.to_s
	end

	def	children
		self.childNodes.to_a
	end

	def	next
		self.nextSibling
	end

	def	text?
		self.nodeType == org.w3c.dom.Node::TEXT_NODE 
	end

	def	element?
		self.nodeType == org.w3c.dom.Node::ELEMENT_NODE 
	end

	def	parent
		self.parentNode
	end

	def	child
		self.firstChild
	end

	# XPathオブジェクトを返す
	#
	# TODO: XPathオブジェクト1つで使いまわしてみたが・・・
	# evaluateの都度生成よりはいいような気がするがどうだろう
	def	get_xpath
		if !@@xpath
			factory = javax.xml.xpath.XPathFactory.newInstance()
			@@xpath = factory.newXPath()
		end

		@@xpath
	end

	# 指定されたノードに対するxpath式のクエリ結果を返す
	#
	# expr::
	#  XPath式
	def	find(expr)
		nodelist = self.get_xpath.evaluate(expr, self, javax.xml.xpath.XPathConstants::NODESET)

		nodelist.to_a
	end

end

JavaUtilities.extend_proxy('org.w3c.dom.Text') do
	def	to_s
		self.nodeValue.to_s
	end
end

# org.w3c.dom.Elementにユーティリティメソッド
JavaUtilities.extend_proxy('org.w3c.dom.Element') do
	def	[](name)
		self.getAttribute(name)
	end

	def	[]=(name, val)
		self.setAttribute(name, val.to_s)
	end
end



module	XMLUtil

	module	XML

		# 空のDocumentを生成して返す
		#
		def	new_document
			factory = javax.xml.parsers.DocumentBuilderFactory.newInstance()
			builder = factory.newDocumentBuilder()
			builder.newDocument
		end

		# 指定されたファイルをopenしてXML文書を返す
		#
		# fn_in::
		#   ファイル名。nilの場合、stdinを適用
		def build_document(fn_in)
			st = java.lang.System.in
			opened = nil
			if fn_in
				opened = st = java.io.FileInputStream.new(fn_in)
			end
	
			factory = javax.xml.parsers.DocumentBuilderFactory.newInstance()
			builder = factory.newDocumentBuilder()
			doc = builder.parse(st)
			if opened
				opened.close
			end
	
			doc
		end

		# XML文書をストリームに書き出す
		#
		# doc::
		#   XML文書、org.w3c.dom.Node
		# st::
		#   出力ストリーム、java.io.OutputStream
		# enc::
		#   出力エンコード
		# omit_xml_decl::
		#   XML宣言出力するかどうか。"yes" | "no"
		# pretty::
		#   フォーマット有無。
		#   でもjavaの場合xalan使わないとインデント付にならない様子
		#   JREのみでは改行挿入が関の山
		def	write_document(doc, st, enc = "utf-8", omit_xml_decl = false, pretty=false)
    	factory = javax.xml.transform.TransformerFactory.newInstance
    	transformer = factory.newTransformer
    	transformer.setOutputProperty(javax.xml.transform.OutputKeys::ENCODING, enc)
    	transformer.setOutputProperty(javax.xml.transform.OutputKeys::OMIT_XML_DECLARATION, omit_xml_decl ? "yes" : "no")
			if pretty
    		transformer.setOutputProperty(javax.xml.transform.OutputKeys::INDENT, "yes")
			end
    	transformer.transform(javax.xml.transform.dom.DOMSource.new(doc), javax.xml.transform.stream.StreamResult.new(st))
		end
	end
end

# vi: ts=2 sw=2 noexpandtab

