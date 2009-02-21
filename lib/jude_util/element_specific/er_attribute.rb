
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# ER属性
		class	TreatERAttribute < JudeElement
			def	initialize
				super("er_attribute")
			end

			def	doit(el, e, index)
				# JUDE5.3から、
				# ドメイン指定の属性の場合、ドメインに設定したデータ型/長さが
				# とれるようだ
				# 初期値は持ってこないようだ。
				#
				# 5.2.1の場合、
				#   ドメイン指定ではない属性にgetDomainを呼び出すと例外
				#   ドメイン指定の属性にgetDatatypeを呼び出すと例外
				# だった
				el["data_type"] = self.make_fullname(e.datatype)
				el["length_precision"] = e.lengthPrecision

				if e.domain
					el["domain"] = self.make_fullname(e.domain)
					el["ref_domain"] = e.domain.getId
				end

				el["logical_name"] = e.logicalName
				el["physical_name"] = e.physicalName
				el["default_value"] = e.defaultValue
				el["is_foreign_key"] = e.isForeignKey.to_s
				el["is_not_null"] = e.isNotNull.to_s
				el["is_primary_key"] = e.isPrimaryKey.to_s
			end
		end

	end

end


# vi: ts=2 sw=2

