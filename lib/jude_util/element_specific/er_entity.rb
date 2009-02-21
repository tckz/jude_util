
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# ERエンティティ
		class	TreatEREntity < JudeElement
			def	initialize
				super("entity")
			end

			def	doit(el, e, index)
				el["logical_name"] = e.logicalName
				el["physical_name"] = e.physicalName
				el["type"] = e.type
				# refs #5 インデックス
				self.process_childs("indices", el, e, e.getERIndices)
				self.process_childs("primary_keys", el, e, e.primaryKeys)
				self.process_childs("non_primary_keys", el, e, e.nonPrimaryKeys)
				self.process_childs("parent_relationships", el, e, e.parentRelationships)
				self.process_childs("children_relationships", el, e, e.childrenRelationships)
			end
		end

	end

end


# vi: ts=2 sw=2

