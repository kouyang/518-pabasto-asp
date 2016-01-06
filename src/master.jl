using MNIST

### TYPE DEFINITION ###

@with_kw type MasterState
	master_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), myid())
	shared_pserver_mailbox = RemoteChannel(() -> PABASTO.IntervalMailbox(), myid())
	workers::Array = Tuple{Int, Any, Any}[]
	paramservers::Array = Tuple{Int, Any}[]
	num_train_examples
	num_processed_examples=0
	num_epoch=1
	max_num_epochs
	time_var=now()
	# parameters for adaptive control policy
	tau

	num_workers
	num_paramservers
	# number of examples the master sends to worker in response to ExamplesRequestMessage
	examples_batch_size
	num_live_workers=0
	num_live_pservers=0
	params=nothing
	num_processed_params=0
end

### INITIALIZATION ###

function initialize_nodes(state::MasterState)
	add_paramservers(state, state.num_paramservers)
	add_workers(state, state.num_workers)
end

function add_paramservers(state::MasterState, count)
	ids = add_procs(count)
	for id in ids
		index=length(state.paramservers)+1
		pserver_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		#remotecall_fetch(paramserver_setup, id, state.master_mailbox, pserver_mailbox,index)
		ref = @spawnat id PABASTO.paramserver(state.master_mailbox, state.shared_pserver_mailbox,pserver_mailbox,index)
		@async wait(ref)
		push!(state.paramservers, (id, pserver_mailbox))
	end
	state.num_live_pservers += count
end

function remove_paramserver(state::MasterState)
	id, ref, pserver_mailbox = pop!(state.paramservers)
	put!(pserver_mailbox, CeaseOperationMessage())
end

function add_workers(state::MasterState, count)
	ids = add_procs(count)
	for id in ids
		worker_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		ref = @spawnat id PABASTO.worker(id, state.master_mailbox, worker_mailbox)
		@async wait(ref)
		push!(state.workers, (id, ref, worker_mailbox))
	end
	state.num_live_workers += count
end

function remove_worker(state::MasterState)
	id, ref, worker_mailbox = pop!(state.workers)
	put!(worker_mailbox, FinishOperationMessage())
end

### REQUEST HANDLING ###

# Handle request from workers for more examples
function handle(state::MasterState,request::ExamplesRequestMessage)

	if state.num_processed_examples >= state.num_train_examples && state.num_epoch < state.max_num_epochs
		state.num_processed_examples = 0;
		state.num_epoch = state.num_epoch + 1;
	elseif state.num_processed_examples >= state.num_train_examples
		# notify all workers to stop
		for (id, ref, worker_mailbox) in state.workers
			put!(worker_mailbox, FinishOperationMessage())
		end
		return
	end

	id = request.id
	worker_mailbox = request.worker_mailbox

	count = 0;
	examples = []
	while count < state.examples_batch_size && state.num_processed_examples < state.num_train_examples
		example_id = state.num_processed_examples + 1
		push!(examples, example_id)
		count = count + 1
		state.num_processed_examples = state.num_processed_examples + 1
	end


	put!(worker_mailbox, ExampleIndicesMessage(examples))
	println("[MASTER] Assigned examples $(examples[1])-$(examples[end]) to worker $(id)")
end

function handle(state::MasterState,msg::FinishedOperationMessage)
	state.num_live_workers -= 1
end

function handle(state::MasterState,msg::CeasedOperationMessage)
	state.num_live_pservers -= 1
end

function handle(state::MasterState,msg::GradientUpdateMessage)
	println("[MASTER] Dispatching GradientUpdateMessage")
	#any paramserver between 1 and 10000 can handle the gradinet update message
	put!(state.shared_pserver_mailbox,msg,1,10000)
end

function handle(state::MasterState,msg::ParameterUpdateRequestMessage)
	println("[MASTER] Dispatching ParameterUpdateRequestMessage")
	put!(state.shared_pserver_mailbox,msg,1,10000)
end

function handle(state::MasterState,msg::ParameterUpdateMessage)
	if state.params == nothing
		state.params = msg.parameters
	end

	new_params = msg.parameters
	operand = half_subtract(new_params, state.params)
	state.params = add(state.params, operand)

	state.num_processed_params += 1
	
end

function handle(state::MasterState,msg::Void)
	println("[MASTER] Spinning")
	sleep(1)
end

function master()
	train_examples, train_labels = traindata()

	state = MasterState(
	num_train_examples=size(train_examples,2), 
	max_num_epochs=100, 
	tau=20.0,
	num_workers=8,
	num_paramservers=8,
	examples_batch_size=100,
	)
	initialize_nodes(state)
	
	while state.num_live_workers > 0
		handle(state,take!(state.master_mailbox))
	end

	state.num_paramservers = state.num_live_pservers
	
	# query each paramserver for parameters
	for (id, ref, pserver_mailbox) in state.paramservers
		put!(pserver_mailbox, ParameterRequestMessage())
	end
	
	while state.num_processed_params < state.num_paramservers
		handle(state,take!(state.master_mailbox))
	end
	
	# all paramservers have sent parameters so shut them all down
	for(id, ref, pserver_mailbox) in state.paramservers
		put!(pserver_mailbox, CeaseOperationMessage())
	end
	
	# write params to disk
	f = open("params.jls", "w")
	serialize(f, state.params.data)
	close(f)
end
