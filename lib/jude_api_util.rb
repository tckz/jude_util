# = JUDE-API系のユーティリティ
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

require	'java'

module Jude
	include_package "com.change_vision.jude.api.inf.project"
	include_package "com.change_vision.jude.api.inf.exception"
	include_package "com.change_vision.jude.api.inf.editor"
	include_package "com.change_vision.jude.api.inf.model"
end

module	JudeAPIUtil
	# Judeファイルを開く
	# 存在しない場合は作成しちゃう
	#
	# fn::
	#   ファイル名
	# is_read_only::
	#   読み取り専用open
	def	open_jude(fn, is_read_only)
		pa = Jude::ProjectAccessorFactory.projectAccessor
		if !File.exist?(fn)
			pa.create(fn)
		else
			pa.open(fn, false, is_read_only ? false : true, is_read_only ? true : false )
		end

		pa
	end


	# フル名を返す
	#
	#   プロジェクト/
	#     パッケージA/
	#       パッケージB/
	#         クラスA
	# なら、"パッケージA::パッケージB::クラスA"
	#
	# そもそも名前が付いていないものは空文字とする。
	# 基点から徐々にownerを辿ってフル名とする。
	# 名前中の各要素は「::」で連結
	# 
	# rootのnameはフル名に含めない。
	# というのは、Projectの名前（ファイル名）が含まれちゃうから。
	# 考えてみれば、ownerがいない場合は連結しない、で良かったのか。。
	#
	# IPackage直下のISequenceDiagramのownerがnilなのは何で？？
	# 
	# root::
	#  ownerを辿る際の行き止まり
	# e::
	#  フル名を作成したいJUDE要素
	def	make_fullname(root, e)
		if !e.java_kind_of? Jude::INamedElement
			return	""
		end
		n = e.name.to_s
		if n == ""
			return	n
		end

		while p = e.owner
			if p == root
				break
			end
			n = p.name + '::' + n
			e = p
		end

		n
	end

	# alias1を得る
	#
	# forceが真なら、
	# alias1が付いてない場合（かつINamedElementなら）代わりにnameを返す
	#
	# e::
	#  JUDE要素
	# force::
	#  alias1が付いてなければ空文字なのだがその場合でも代わりにnameを返す指定
	def	make_alias1(e, force=true)
 		# 5.4からAPIが新設された
 		ret = ""
 		if e.java_kind_of? Jude::INamedElement
 			ret = e.alias1.to_s
 			if force and ret == ""
 				ret = e.name
 			end
		end

		ret
	end

	# タグ付き値を返す
	#
	# e::
	#  IElement
	# key::
	#  タグ名
	def	find_tagged(e, key)
		ret = nil
		if e.java_kind_of? Jude::IElement
			e.taggedValues.each { |t|
				if t.key == key
					return t.value
				end
			}
		end

		ret
	end

	# フル名の英語版を返す
	#
	# forceが真なら、
	# alias1が付いてない場合代わりにnameを返す
	# 
	# root::
	#  ownerを辿る終点
	# e::
	#  名前を得たいJUDE要素
	# force::
	#  alias1が付いてなければ空文字なのだがその場合でも代わりにnameを返す指定
	def	make_full_alias1(root, e, force=true)
		n = self.make_alias1(e, force).to_s
		if n == ""
			return	n
		end
		while p = e.owner
			if p == root
				break
			end
			n = self.make_alias1(p, force) + '::' + n
			e = p
		end

		n
	end

	# 編集API絡み
	module	ModelEditor
		@er_model_editor = nil

		def	er_model_editor
			if !@er_model_editor
				@er_model_editor = Jude::ModelEditorFactory.getERModelEditor()
			end

			@er_model_editor
		end

		# Judeトランザクションで囲ってブロックを実行
		# ブロックから例外が出たらabort、出なければcommit
		#
		# b::
		#   ブロック
		def	do_txn(&b)
			Jude::TransactionManager.beginTransaction()
			ret = nil
			begin
				ret = b.call
				Jude::TransactionManager.endTransaction
			rescue => ex
				Jude::TransactionManager.abortTransaction
				raise
			end

			ret
		end

		# 属性一個分作成・更新する
		#
		# ent::
		#   IEREntity
		# attr_obj::
		#   IERAttribute
		#   新規作成の場合はnil
		# e::
		#   エンティティの情報が入ったHash
		# a::
		#   属性の情報が入ったHash
		# options::
		#   options.domain_typeをドメインのデフォルト型名として使う
		def	update_attribute(ent, attr_obj, e, a, options)
		
			domain_obj = datatype_obj = nil
			domain = a[:domain].to_s
			if domain != ""
				# ドメイン指定がある場合はドメインを優先

				# ドメインの型は、データ型が指定されていればこれを適用
				# なければ、オプションでデフォルト指定した型
				domain_type = a[:type] != "" ? a[:type] : options.domain_datatype

				domain_obj = datatype_obj = self.find_domain(domain, {
					:physicalname => "",
					:datatype => self.find_datatype(domain_type)
				})
			else
				# データ型
				# なければ作る
				if a[:type].to_s == ""
					raise "attr's type must be specified." 
				end
				datatype_obj = self.find_datatype(a[:type])
			end

			# 論理名がないとcreateERAttributeで例外が出る
			if a[:logicalname] == ""
				raise "attr's logicalname must be specified." 
			end

			if attr_obj
				# 更新
				attr_obj.logicalName = a[:logicalname].to_s
				attr_obj.physicalName = a[:physicalname].to_s

				if domain_obj
					attr_obj.domain = domain_obj
				else
					attr_obj.datatype = datatype_obj
				end
			else
				# 新規
				attr_obj = self.er_model_editor.createERAttribute(ent, a[:logicalname], a[:physicalname], datatype_obj)
			end

			# ドメイン指定でない場合で
			if !domain_obj 
				# 1以上の数字の場合だけ長さを設定
				if a[:length] && a[:length].to_i > 0
					attr_obj.lengthPrecision = a[:length].to_i.to_s
				end
			end

			# 5.3.0だとAPIでERドメインに対してはNOT NULLを設定できない
			if a[:nn]
				attr_obj.setNotNull(a[:nn] != "" ? true : false)
			end

			# デフォルト値
			if a[:default] && a[:default] != ""
				attr_obj.defaultValue = a[:default]
			end

			# PK
			if a[:pk]
				attr_obj.setPrimaryKey(a[:pk] != "" ? true : false)
			end

			attr_obj
		end
	end

	# Judeプロジェクト中のオブジェクトへのアクセスパス
	module	ShortCutJudeProject

		# ショートカットテーブルを作成する
		# JUDEプロジェクトのrootから再帰的に辿って発見した要素を登録
		#
		# root::
		#   Judeプロジェクト
		def	load_short_cut(root)
			@short_cut = {
				:by_type => {
					:er_schema => [],
					:er_model => [],
					:er_entity => [],

					# 名前で探したい
					:er_datatype => {},
					:er_domain => {},
				},
				:by_stereotype => {
				},
			}

			do_traverse = proc { |e|
				self.register_short_cut(e)

				children = []
				if e.java_kind_of? Jude::IERSchema
					children.concat(e.entities.to_a + e.datatypes.to_a + e.domains.to_a)
				elsif e.java_kind_of? Jude::IERDomain
					children.concat(e.children)
				end

				if e.java_kind_of? Jude::IPackage
					children.concat(e.ownedElements.to_a)
				end

				children.each { |d|
					do_traverse.call(d)
				}
			}

			do_traverse.call(root)

		end

		# ショートカットテーブルにJUDE要素を登録
		#
		# e::
		#   JUDE要素
		def	register_short_cut(e)
			name = e.name
			if e.java_kind_of? Jude::IElement
				e.stereotypes.each {|st|
					h = @short_cut[:by_stereotype][st]
					if !h
						h = @short_cut[:by_stereotype][st] = []
					end

					h.push(e)
				}
			end

			if e.java_kind_of? Jude::IERSchema
				@short_cut[:by_type][:er_schema].push(e)
			elsif e.java_kind_of? Jude::IERModel
				@short_cut[:by_type][:er_model].push(e)
			elsif e.java_kind_of? Jude::IERDatatype
				@short_cut[:by_type][:er_datatype][name] = e
			elsif e.java_kind_of? Jude::IERDomain
				@short_cut[:by_type][:er_domain][name] = e
			elsif e.java_kind_of? Jude::IEREntity
				@short_cut[:by_type][:er_entity].push(e)
			end
		end

		def	enum_er_entities
			@short_cut[:by_type][:er_entity]
		end

		def	enum_boundaries
			@short_cut[:by_stereotype]["boundary"]
		end

		def	enum_entities
			@short_cut[:by_stereotype]["entity"]
		end

		def	enum_controls
			@short_cut[:by_stereotype]["control"]
		end

		# データ型を探して返す
		#
		# name::
		#   データ型の名前
		# create::
		#   ショートカット内に存在しない場合に作成するかどうか
		def	find_datatype(name, create = true)

			dt = @short_cut[:by_type][:er_datatype][name]

			# 5.3.0：編集API経由で登録すると小文字が大文字になる
			# このためショートカットがhitしなくなる。ので大文字で再try
			# でもGUIからは小文字のままデータ型を登録できる。。。
			if !dt
				dt = @short_cut[:by_type][:er_datatype][name.upcase]
			end

			if !dt && create
				#pp [ "create datatype" , name,create]
				# 未知のデータタイプなら作成
				dt = self.er_model_editor.createERDatatype(self.find_er_model, name)
				self.register_short_cut(dt)
			end

			dt
		end

		# ドメインを探して返す
		# 見つからない場合で、作成オプションがついていれば、作成して返す
		#
		# name::
		#   ドメインの論理名
		# create::
		#   ドメイン作成オプション、Hash
		def	find_domain(name, create = nil)
			domain_obj = @short_cut[:by_type][:er_domain][name]
			if !domain_obj && create
				#pp [ "create domain" , name,create]
				# 未知のドメインなら作成
				domain_obj = self.er_model_editor.createERDomain(self.find_er_model, create[:parent], name, create[:physicalname], create[:datatype])
				self.register_short_cut(domain_obj)
			end

			domain_obj
		end

		# ショートカットテーブルからIERSchemaを探して返す
		#
		def	find_er_schema
			# TODO: JUDEがスキーマを複数持つようになったら困る
			@short_cut[:by_type][:er_schema][0]
		end

		# ショートカットテーブルからIERModelを探して返す
		#
		def	find_er_model
			# TODO: JUDEがERモデルを複数持つようになったら困る
			@short_cut[:by_type][:er_model][0]
		end
	end
end

# vi: ts=2 sw=2

