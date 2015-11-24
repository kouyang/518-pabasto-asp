using AutoDiff

#=
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
=#

using MNIST
using Images,ImageView

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

weights1=Variable(0.01*randn((10,784)))
biases1=Variable(0.01*randn((10,)))
function prediction(digit)
	layer1=rect_lin(weights1*digit.+biases1)
	tmp=exp(layer1)
	tmp./sum(tmp)
end

begin #viewing 
	function f(x)
		a=x-minimum(x)
		a/=maximum(a)
		grayim(transpose(reshape(a,(28,28))))
	end
	#c = canvasgrid(4,5)
	function updateview()
		for i in 1:10
			#view(c[i],f(val(weights1)[i,:]))
		end
	end
end

error=sum((prediction(digit)-label).^2)
running_mean=0
using ProfileView
minimize(error,delta=0.0001,its=10)
Profile.clear_malloc_data()
minimize(error,delta=0.0001,its=10000000,f=(it->begin
	global running_mean
	running_mean=0.9999*running_mean+0.0001*val(error)
	if it%1000==0
		println("Mean error: $(running_mean)")
		updateview()
	end
end
))
ProfileView.view()
