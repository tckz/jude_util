
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# ERリレーションシップ
		class	TreatERRelationship < JudeElement
			def	initialize
				super("relationship")
			end

			def	doit(el, e, index)
				if e.parent
					el["parent"] = self.make_fullname(e.parent)
					el["ref_parent"] = e.parent.getId
				end
				if e.child
					el["child"] = self.make_fullname(e.child)
					el["ref_child"] = e.child.getId
				end

				if e.foreignKeys.size > 0
					el_fks = el.doc.createElement("foreign_keys")
					e.foreignKeys.each { |a|
						el_fk = el.doc.createElement("foreign_key")
						el_fk["key"] = self.make_fullname(a)
						el_fk["ref_key"] = a.getId
						el_fks << el_fk
					}
					el << el_fks
				end

				el["verb_to_child"] = e.verbPhraseChild.to_s
				el["verb_to_parent"] = e.verbPhraseParent.to_s

				el["is_parent_required"] = e.isParentRequired.to_s
				el["is_identifying"] = e.isIdentifying.to_s
				el["is_non_identifying"] = e.isNonIdentifying.to_s
				el["is_multi_to_multi"] = e.isMultiToMulti.to_s
			end
		end

	end

end


# vi: ts=2 sw=2

