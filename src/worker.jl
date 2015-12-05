### Worker State ###
type WorkerState
	current_params::Parameter
	meta_params
	dataset
	examples
	master_channel
	master_recv_channel
	master_control_channel
	pserver_gradient_update_channel
	pserver_update_request_channel
	pserver_recv_update_channel
	tau
end

include("gradient_computations.jl")

# main worker loop
function worker(id, master_channel, master_recv_channel, master_control_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
	
	state = WorkerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]), nothing, nothing, nothing, master_channel, master_recv_channel, master_control_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel, 5.0)
	
	time_var = now();
	param_update_request_sent = false;
	
	while true
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
		
		if length(state.examples) == 0
			break
		end
		
		# compute gradient using assigned indices
		grad = compute_gradient(state.current_params, state.examples);
		
		# examples processed - reset field so that worker knows to request more examples
		state.examples = nothing;
		
		println("[WORKER] Sending gradient updates")
		put!(state.pserver_gradient_update_channel, GradientUpdateMessage(grad));
		
		if isready(state.pserver_recv_update_channel)
			msg = take!(state.pserver_recv_update_channel);
			state.current_params = msg;
			time_var = now();
			param_update_request_sent = false;
			println("[WORKER] Worker has received and processed parameter value update")
		end
		
		time_tmp = now();
		# time in milliseconds
		time_elapsed = Int(time_tmp - time_var);
		
		if time_elapsed >= state.tau * 1000 && !param_update_request_sent
			println("[WORKER] Requesting parameter value updates")
			println("Time elapsed (in ms) since last parameter value update request is ", time_elapsed);
			put!(state.pserver_update_request_channel, ParameterUpdateRequestMessage(state.pserver_recv_update_channel));
			param_update_request_sent = true;
		end
		
		if isready(state.master_control_channel)
			msg = take!(master_control_channel);
			state.tau = msg.tau;
			println("[WORKER] Worker has received and processed control policy message")
		end
		
	end
end
