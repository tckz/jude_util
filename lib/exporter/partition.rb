
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# パーティション
		class	TreatPartition < JudeElement
			def	initialize
				super("partition")
			end

			def	doit(el, e, index)
				el["is_horizontal"] = e.isHorizontal.to_s

				if e.previousPartition
					el["ref_previous_partition"] = e.previousPartition.getId
				end

				if e.nextPartition
					el["ref_next_partition"] = e.nextPartition.getId
				end

				if e.superPartition
					el["ref_super_partition"] = e.superPartition.getId
				end

				self.process_childs("partitions", el, e, e.subPartitions)

				self.enum_link(el, "activity_node_link", e.activityNodes)
			end
		end

	end

end


# vi: ts=2 sw=2

