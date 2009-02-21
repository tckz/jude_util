
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# アクティビティ
		class	TreatActivity < JudeElement
			def	initialize
				super("activity")
			end
			def	doit(el, e, index)
				self.process_childs("partitions", el, e, e.partitions)
				self.process_childs("activity_nodes", el, e, e.activityNodes)
				self.process_childs("flows", el, e, e.flows)
			end
		end

	end

end


# vi: ts=2 sw=2

