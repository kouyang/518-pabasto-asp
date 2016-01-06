### Param Server State ###

const DISPLAY_FILTERS=false

if DISPLAY_FILTERS
	using Images, ImageView
end

@with_kw type ParamServerState
	params
	master_mailbox
	shared_pserver_mailbox
	pserver_mailbox
	accumulated_gradients=SimpleGradient(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1])
	n_accumulated_gradients=0
	index::Int
	time_var=now()
	param_request_pending::Bool=false
	tau=5
	exit::Bool=false
end

function paramserver(master_mailbox, shared_pserver_mailbox,pserver_mailbox, index)
	state = ParamServerState(
	params=SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]),
	master_mailbox=master_mailbox,
	shared_pserver_mailbox=shared_pserver_mailbox,
	pserver_mailbox=pserver_mailbox,
	index=index)
	println("[PARAM SERVER] initialized")

	while !state.exit
		msg=take!(state.pserver_mailbox)
		if msg==nothing
			msg=take!(state.shared_pserver_mailbox,state.index)
		end
		#handle(state,take!(state.pserver_mailbox))
		handle(state,msg)
		if state.index>=2
			low=max(state.index/4,1)
			high=min(state.index/2,state.index-1)
			@assert high >= low
			if state.n_accumulated_gradients > 2
				println("[PARAM SERVER] Pushing gradients")
				put!(state.shared_pserver_mailbox,GradientUpdateMessage(state.accumulated_gradients),low,high)
				state.accumulated_gradients.data*=0
				state.n_accumulated_gradients=0
			end
			time_elapsed = Int(now() - state.time_var)
			if time_elapsed >= state.tau * 1000 && !state.param_request_pending
				println("[PARAM SERVER] Requesting parameter value updates")
				println("[PARAM SERVER] Time last parameter update request: $(time_elapsed)ms");
				put!(state.shared_pserver_mailbox, ParameterUpdateRequestMessage(state.pserver_mailbox),low,high);
				state.param_request_pending = true;
			end
		end
	end

	put!(local_state.master_mailbox, CeasedOperationMessage(id))
	println("[PARAM SERVER] Shutting down")
end

function handle(state:: ParamServerState, message::Void)
	#println("[PARAM SERVER] Spinning")
	#sleep(0.01)
end

function handle(state::ParamServerState, message::ParameterUpdateMessage)
	state.params.data = message.parameters.data
	state.time_var = now()
	state.param_request_pending=false
	println("[PARAM SERVER] Processed parameter value update")
end

function handle(state::ParamServerState, message::ParameterUpdateRequestMessage)
	println("[PARAM SERVER] Reading params")
	put!(message.worker_mailbox,ParameterUpdateMessage(state.params))
end

function updateview()
	for i in 1:10
		view(c[i],f(local_state.params.data[1][i,:]),interactive=false)
	end
end
function f(x)
	a=x-minimum(x)
	a/=maximum(a)
	grayim(transpose(reshape(a,(28,28))))
end
function handle(state::ParamServerState,message::GradientUpdateMessage)
	println("[PARAM SERVER] Writing params")
	update(state.params, fetch(message.gradient))
	state.n_accumulated_gradients+=1
	if DISPLAY_FILTERS
		updateview()
	end
end

function handle(message::CeaseOperationMessage)
	global local_state
	local_state.exit = true
end
