###Worker State###
type WorkerState
	current_params::Parameter
	meta_params
	dataset
	master_recv_channel
	master_send_channel
	pserver_gradient_update_channel
	pserver_update_request_channel
	pserver_recv_update_channel
end

function compute_gradient(params,dataset)
	println("Computing gradients")
	sleep(1)
	#fill me
	return ConcreteGradient()
end

#main worker loop
function worker(master_recv_channel, master_send_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
	state=WorkerState(ConcreteParameter(),nothing, nothing, master_recv_channel, master_send_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
	for i in 1:10
		grad=compute_gradient(state,dataset);
		
		println("Sending gradient updates")
		put!(state.pserver_gradient_update_channel, GradientUpdateMessage(grad));
		
		println("Requesting parameter value updates")
		put!(state.pserver_update_request_channel, ParameterUpdateRequestMessage(state.pserver_recv_update_channel));
		
		#=
		boo1 = isready(state.master_recv_channel);
		
		if boo1
			break
		end
		=#
		
		boo2 = isready(state.pserver_recv_update_channel);
		
		if boo2
			msg = take!(state.pserver_recv_update_channel);
			state.current_params = msg.parameter;
			println("Worker has received and processed parameter value update")
		end
		
	end
end
