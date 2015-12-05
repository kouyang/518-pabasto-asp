### Worker State ###
type WorkerState
	current_params::Parameter
	meta_params
	dataset
	examples
	master_channel
	master_recv_channel
	pserver_gradient_update_channel
	pserver_update_request_channel
	pserver_recv_update_channel
end

include("gradient_computations.jl")
# main worker loop
function worker(id, master_channel, master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
	state = WorkerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]), nothing, nothing, nothing, master_channel, master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
	for i = 1:10
		if state.examples == nothing
			has_examples = isready(state.master_recv_channel)
			if !has_examples
				println("[WORKER] Requesting examples")
				put!(state.master_channel, ExamplesRequestMessage(id, state.master_recv_channel))
			end
			# read dataset with indices in master_recv_channel
			msg = take!(state.master_recv_channel);
			state.examples = msg.indices;
		end
		
		# compute gradient using assigned indices
		grad = compute_gradient(state.current_params, state.examples);
		
		# examples processed - reset field so that worker knows to request more examples
		state.examples = nothing;
		
		println("[WORKER] Sending gradient updates")
		put!(state.pserver_gradient_update_channel, GradientUpdateMessage(grad));
		
		println("[WORKER] Requesting parameter value updates")
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
			state.current_params = msg;
			println("[WORKER] Worker has received and processed parameter value update")
		end
	end
end
