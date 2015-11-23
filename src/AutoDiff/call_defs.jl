function def_diff_binary(f::Symbol)
	eval(
	quote
		$f(x::CoTangent,y::CoTangent)=Call($f,(x,y))
		$f(x::CoTangent,y)=Call($f,(x,y))
		$f(x,y::CoTangent)=Call($f,(x,y))
	end
	)
end
function def_diff_unary(f::Symbol)
	eval(
	quote
		$f(x::CoTangent)=Call($f,(x,))
	end
	)
end
map(def_diff_binary,[:+,:*,:-,:/,:.+,:.-,:.*,:./,:.^])
map(def_diff_unary,[:-,:sigmoid,:rect_lin,:exp,:log,:sum])
