
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# ハイパーリンク
		class	TreatHyperlink < JudeElement
			def	initialize
				super("hyperlink")
			end

			def	doit(el, e, index)
				el["comment"] = e.comment
				el["name"] = e.name
				el["path"] = e.path
				el["is_file"] = e.isFile.to_s
				el["is_model"] = e.isModel.to_s
				el["is_url"] = e.isURL.to_s
			end
		end

	end

end


# vi: ts=2 sw=2

