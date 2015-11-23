using AutoDiff

x=Variable(2.0)
y=Variable(4.0)

z=(x-1)^2+(y-3)^2
println(z)
minimize(z)
println("x: $(val(x))")
println("y: $(val(y))")

#same computation as above, vectorized
z=sum((Lift([Variable(2.0), Variable(5.0)])-[1.0,3.0]).^2)
println(z)
minimize(z)
println("x: $(val(x))")
println("y: $(val(y))")

#=
using MNIST

N=60000
data=traindata()[1][:,1:N]/256
raw_labels=traindata()[2][1:N]
labels=zeros(Float64,(10,N))
for i in 1:length(raw_labels)
	labels[raw_labels[i]+1,i]=1.0
end

currdigit=0
function getdigit()
	global currdigit=(currdigit+1)%N
	data[:,currdigit+1]
end
function getlabel(digit)
	labels[:,currdigit+1]
end

digit=Call(getdigit,())
label=Call(getlabel,(digit,))

weights1=Variable(randn((10,784)))
biases1=Variable(randn((10,)))
function prediction(digit)
	layer1=rect_lin(weights1*digit.+biases1)
	tmp=exp(layer1)
	tmp./sum(tmp)
end

error=sum((prediction(digit)-label).^2)
running_mean=0
minimize(error,its=500000,f=(it->begin
	global running_mean
	running_mean=0.999*running_mean+0.001*val(error)
	if it%1000==0
		println("Mean error: $(running_mean)")
	end
end
))
=#
