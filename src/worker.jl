###Worker State###
type WorkerState
	current_params::Parameter
	meta_params
	dataset
	master_channel
	pserver_recv_channel
	pserver_send_channel
	worker_id
	pserver_id
end

function compute_gradient(params,dataset)
	println("Computing gradients")
	sleep(1)
	#fill me
	return ConcreteGradient()
end

#main worker loop
function worker(master_channel, pserver_recv_channel, pserver_send_channel, worker_id, pserver_id)
	state=WorkerState(ConcreteParameter(),nothing, nothing, master_channel, pserver_recv_channel, pserver_send_channel, worker_id, pserver_id)
	for i in 1:10
		grad=compute_gradient(state,dataset)

		#fetch parameters
		state.current_params=fetch(remotecall(state.pserver_id,read_params))

		#write params to parameter server
		remotecall(state.pserver_id,write_params,grad)
	end
end
