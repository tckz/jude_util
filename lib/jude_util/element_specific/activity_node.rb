
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# アクティビティノード
		class	TreatActivityNode < JudeElement
			def	initialize
				super("activity_node")
			end
			def	doit(el, e, index)

				self.enum_link(el, "incoming", e.incomings)
				self.enum_link(el, "outgoing", e.outgoings)
			end
		end

	end

end


# vi: ts=2 sw=2

