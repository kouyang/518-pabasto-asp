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
	accumulated_gradients
	n_accumulated_gradients=0
	index::Int
	time_var=now()
	param_request_pending::Bool=false
	tau=0.5
	exit::Bool=false
	hyper_params::HyperParameters
end
function initialize_view()
	if DISPLAY_FILTERS
		global c = canvasgrid(4,5)
	end			
end

function paramserver(master_mailbox, shared_pserver_mailbox,pserver_mailbox, index,starting_params, hyper_params)

	state = ParamServerState(
	params=starting_params,
	accumulated_gradients=SimpleGradient(sample_parameters(var=0.0),starting_params.timestamp,starting_params.discrete_timestamp,0),
	master_mailbox=master_mailbox,
	shared_pserver_mailbox=shared_pserver_mailbox,
	pserver_mailbox=pserver_mailbox,
	index=index,
	hyper_params=hyper_params
	)
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
			time_elapsed = Int(now() - state.time_var)
			if time_elapsed >= state.tau * 1000 && !state.param_request_pending
				println("[PARAM SERVER] Requesting parameter value updates")
				println("[PARAM SERVER] Time last parameter update request: $(time_elapsed)ms");
				put!(state.shared_pserver_mailbox, ParameterUpdateRequestMessage(state.pserver_mailbox),low,high);
				state.param_request_pending = true;
			end
		end
	end

	put!(state.master_mailbox, CeasedOperationMessage(myid()))
	println("[PARAM SERVER] Shutting down")
end

function handle(state:: ParamServerState, message::Void)
	yield()
	#println("[PARAM SERVER] Spinning")
	#sleep(0.01)
end

function handle(state::ParamServerState, message::ParameterUpdateMessage)
	state.params = message.parameters
	state.time_var = now()
	state.param_request_pending=false
	println("[PARAM SERVER] Processed parameter value update")
end

function handle(state::ParamServerState, message::ParameterUpdateRequestMessage)
	println("[PARAM SERVER] Reading params")
	@schedule begin
		put!(message.worker_mailbox,ParameterUpdateMessage(state.params))
	end
end

function updateview(state)
	for i in 1:10
		view(c[i],f(state.params.data[1][i,:]),interactive=false)
	end
end
function f(x)
	a=x-minimum(x)
	a/=maximum(a)
	grayim(transpose(reshape(a,(28,28))))
end
function handle(state::ParamServerState,message::GradientUpdateMessage)
	if state.index==1
		println("[PARAM SERVER] Committing gradients")
		update(state.params, take!(message.gradient))
	else
		println("[PARAM SERVER] Accumulating gradients")
		state.accumulated_gradients.data+=fetch(message.gradient).data
		state.n_accumulated_gradients+=1
		if state.n_accumulated_gradients > 2
			low=max(state.index/4,1)
			high=min(state.index/2,state.index-1)
			@assert high >= low
			println("[PARAM SERVER] Pushing gradients")
			put!(state.shared_pserver_mailbox,GradientUpdateMessage(state.accumulated_gradients),low,high)
			state.accumulated_gradients.data*=0
			state.n_accumulated_gradients=0
		end
	end
	if DISPLAY_FILTERS
		updateview(state)
	end
end

function handle(state::ParamServerState,message::CeaseOperationMessage)
	state.exit = true
end
