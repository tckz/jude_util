
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# タグ付き値
		class	TreatTaggedValue < JudeElement
			def	initialize
				super("tagged_value")
			end

			def	doit(el, e, index)
				el << e.value.to_s
				el["key"] = e.key
			end

		end

	end

end


# vi: ts=2 sw=2

