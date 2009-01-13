
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# コメント
		class	TreatComment < JudeElement
			def	initialize
				super("comment")
			end

			def	doit(el, e, index)
				el << e.body.strip
				el_ans = el.doc.createElement("annotated_elements")
				e.annotatedElements.each {|an|
					el_an = el.doc.createElement("annotated_element")
					el_an["ref"] = an.getId
					el_an["fullname"] = self.make_fullname(an)
					el_ans << el_an
				}
				el << el_ans
			end
		end

	end

end


# vi: ts=2 sw=2

