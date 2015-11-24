macro prop(x,y)
	quote
		if is_CoTangent($x)
			($x).delta+=$y
		end
	end
end

function backprop(x::Variable) end
function backprop(c::Call) 
	backprop_dispatch(c,c.args...)
end
function backprop_dispatch{F}(c::Call{F},args...)
	#println("Warning: no backprop definition for $F on $(map(typeof,args))")
end
function backprop(x::Lift)
	for (a,b) in zip(x.args,x.delta)
		@prop(a,b)
	end
end

function backprop_dispatch(c::Call{:+},args...)
	map(x->@prop(x,c.delta),args)
end

function backprop_dispatch(c::Call{:*},A,B)
	@prop(A,c.delta*transpose(val(B)))
	@prop(B,transpose(val(A))*c.delta)
end

function backprop_dispatch(c::Call{:-},x)
	@prop(x,-c.delta)
end
function backprop_dispatch(c::Call{:-},x,y)
	@prop(x,c.delta)
	@prop(y,-c.delta)
end

function backprop_dispatch(c::Call{:/},A,B)
	@prop(A,c.delta/val(B))
	@prop(B,-c.delta.*val(A)/val(B)^2)
end

function backprop_dispatch(c::Call{:.^},A,n::Real)
	@prop(A,c.delta.*n.*val(A).^(n-1))
end

function backprop_dispatch(c::Call{:sigmoid},A)
	@prop(A, c.delta .* val(c) .* (1.0-val(c)))
end

function backprop_dispatch(c::Call{:rect_lin},A)
	@prop(A,!map(signbit,val(A)).*c.delta)
end

function backprop_dispatch(c::Call{:exp},A)
	@prop(A,c.delta .* val(c))
end

function backprop_dispatch(c::Call{:log},A)
	@prop(A,c.delta./val(A))
end




macro downcast_prop(x,y)
	quote
		if is_CoTangent($x)
			downcast_prop($x,$y)
		end
	end
end

function downcast_prop(c::CoTangent,x)
	#reduction_dims=filter(k->size(c.delta,k)==1,1:length(size(x)))
	reduction_dims=[]
	for i in 1:length(size(x))
		if size(c.delta,i)==1
			push!(reduction_dims,i)
		end
	end
	c.delta+=reshape(sum(x,reduction_dims),size(c.delta))
end
function downcast_prop{T<:Real}(c::CoTangent{T},x)
	c.delta+=sum(x)
end

function backprop_dispatch(c::Call{:.*},A,B)
	@downcast_prop(A,c.delta .* val(B))
	@downcast_prop(B,c.delta .* val(A))
end
function backprop_dispatch(c::Call{:.-},A,B)
	@downcast_prop(A,c.delta)
	@downcast_prop(B,-c.delta)
end
function backprop_dispatch(c::Call{:.-},A)
	@downcast_prop(A,-c.delta)
end
function backprop_dispatch(c::Call{:.+},args...)
	map(x->@downcast_prop(x,c.delta),args)
end

function backprop_dispatch(c::Call{:./},A,B)
	@downcast_prop(A,c.delta./val(B))
	@downcast_prop(B,-c.delta.*val(A)./val(B).^2)
end



macro upcast_prop(x,y)
	quote
		if is_CoTangent($x)
			($x).delta .+= $y
		end
	end
end
function backprop_dispatch(c::Call{:sum},A)
	@upcast_prop(A,Any[c.delta])
end
function backprop_dispatch(c::Call{:sum},A,dims)
	@upcast_prop(A,c.delta)
end



function backprop_dispatch(c::Call{:getindex},A,indices...)
	A.delta[indices...]+=c.delta
end
function backprop_dispatch(c::Call{:permutedims},A,perm)
	@prop(A,ipermutedims(c.delta,perm))
end
