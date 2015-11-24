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
Base.sum(A::CoTangent,dims)=Call(sum,(A,dims))
Base.getindex(A::CoTangent,i)=Call(getindex,(A,i))
Base.getindex(A::CoTangent,i,j)=Call(getindex,(A,i,j))
Base.getindex(A::CoTangent,i,j,k)=Call(getindex,(A,i,j,k))
Base.getindex(A::CoTangent,i,j,k,l)=Call(getindex,(A,i,j,k,l))
Base.permutedims(A::CoTangent,dims)=Call(permutedims,(A,dims))
