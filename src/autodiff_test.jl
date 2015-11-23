using AutoDiff

x=Variable(2.0)
y=Variable(3.0)

minimize((x-1)^2+(y-3)^2)
println("x: $(val(x))")
println("y: $(val(y))")

