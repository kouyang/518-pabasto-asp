macro prop(x,y)
	quote
		if is_CoTangent($x)
			prop($x,$y)
		end
	end
end

function prop(c::CoTangent,x)
	c.delta+=x
end

function backprop(c::Call{:+})
	map(x->@prop(x,c.delta),c.args)
end

function backprop(c::Call{:*})
	@prop(c.args[1],c.delta*transpose(val(c.args[2])))
	@prop(c.args[2],transpose(val(c.args[1]))*c.delta)
end

function backprop(c::Call{:-})
	if length(c.args)==2
		@prop(c.args[1],c.delta)
		@prop(c.args[2],-c.delta)
	else
		@prop(c.args[1],-c.delta)
	end
end

function backprop(c::Call{:/})
	@prop(c.args[1],c.delta/val(c.args[2]))
	@prop(c.args[2],-c.delta.*val(c.args[1])/val(c.args[2])^2)
end

function backprop(c::Call{:.^})
	@prop(c.args[1],c.delta.*val(c.args[2]).*val(c.args[1]).^(val(c.args[2]-1)))
end

function backprop(c::Call{:sigmoid})
	@prop(c.args[1],c.delta .* val(c) .* (1.0-val(c)))
end

function backprop(c::Call{:rect_lin})
	@prop(c.args[1],!map(signbit,val(c.args[1])).*c.delta)
end

function backprop(c::Call{:exp})
	@prop(c.args[1],c.delta .* val(c))
end

function backprop(c::Call{:log})
	@prop(c.args[1],c.delta./val(c.args[1]))
end
