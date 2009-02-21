
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# ヘッダーセル
		class	TreatHeaderCell < JudeElement
			def	initialize
				super("header_cell")
			end

			def	doit(el, e, index)
				el[e.isColumnHeader ? "col" : "row"] = index.to_s
				el["label"] = e.label
				el["visible"] = e.isVisible.to_s
				el["total"] = e.isTotal.to_s
				if e.parent
					el["parent"] = e.parent.label
				end
				if e.model
					el["model"] = self.make_fullname(e.model)
 					# refs #6 IDも
 					el["ref_model"] = e.model.getId
				end
			end
		end


	end

end


# vi: ts=2 sw=2

