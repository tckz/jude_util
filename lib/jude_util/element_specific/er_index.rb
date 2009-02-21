
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# ERインデックス
		# refs #5
		class	TreatERIndex < JudeElement
			def	initialize
				super("er_index")
			end

			def	doit(el, e, index)
				el["kind"] = e.kind
				el["is_unique"] = e.isUnique

				# refs #5 インデックス
				self.enum_link(el, "index_attribute", e.getERAttributes)
			end
		end

	end

end


# vi: ts=2 sw=2

