
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# ERドメイン
		class	TreatERDomain < JudeElement
			def	initialize
				super("domain")
			end

			def	doit(el, e, index)
				el["datatype_name"] = e.datatypeName
				el["default_value"] = e.defaultValue
				el["length_precision"] = e.lengthPrecision
				el["logical_name"] = e.logicalName
				el["physical_name"] = e.physicalName
				el["is_not_null"] = e.isNotNull.to_s

				self.process_childs("child_domains", el, e, e.children)
			end
		end

	end

end


# vi: ts=2 sw=2

