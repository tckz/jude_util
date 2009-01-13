
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# ERデータタイプ
		class	TreatERDatatype < JudeElement
			def	initialize
				super("datatype")
			end

			def	doit(el, e, index)
				el["default_length_precision"] = e.defaultLengthPrecision
				el["description"] = e.description
				el["length_constraint"] = e.lengthConstraint
				el["precision_constraint"] = e.precisionConstraint
			end
		end

	end

end


# vi: ts=2 sw=2

