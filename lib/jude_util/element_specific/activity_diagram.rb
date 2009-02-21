
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# アクティビティ図
		class	TreatActivityDiagram < JudeElement
			def	initialize
				super("activity_diagram")
			end

			def	doit(el, e, index)
				el["is_flowchart"] = e.isFlowChart.to_s

				self.traverse_into(el, e.activity)
			end
		end

	end

end


# vi: ts=2 sw=2

