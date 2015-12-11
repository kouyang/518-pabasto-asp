### Param Server State ###

const DISPLAY_FILTERS=false

if DISPLAY_FILTERS
	using Images, ImageView
end
type ParamServerState
	params
	master_mailbox
	pserver_mailbox
end

local_state = nothing

function paramserver_setup(master_mailbox, pserver_mailbox)
	global local_state = ParamServerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]),master_mailbox,pserver_mailbox)
	if DISPLAY_FILTERS
		global c = canvasgrid(4,5)
	end
end

#Need to decide if paramservers will spin
#=
function paramserver()
	while true
		if isready(master_mailbox) # wrong
			msg = take!(state.master_mailbox)
			if typeof(msg) == CeaseOperationMessage
				println("[PARAM SERVER] Param server $(id) is shutting down")
				return
			end
		end

		output1 = remotecall_fetch(get_pserver_gradient_update_channel, 1)
		output2 = remotecall_fetch(get_pserver_update_request_channel, 1)

		if output2 != nothing
			worker_mailbox = output2.worker_mailbox;
			put!(worker_mailbox, SendParameterUpdateMessage(ConcreteParameter()))
			println("[PARAM SERVER] Parameter update message has been sent to worker")
		end
	end
end
=#

function handle(message::ParameterUpdateRequestMessage)
	global local_state
	println("[PARAM SERVER] Reading params")
	put!(message.worker_mailbox,ParameterUpdateMessage(local_state.params))
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
function handle(message::GradientUpdateMessage)
	global local_state
	println("[PARAM SERVER] Writing params")
	update(local_state.params, message.gradient)
	if DISPLAY_FILTERS
		updateview()
	end
end
