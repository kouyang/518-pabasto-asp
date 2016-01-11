using MNIST

### TYPE DEFINITION ###

@with_kw type MasterState
	master_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), myid())
	shared_pserver_mailbox = RemoteChannel(() -> PABASTO.IntervalMailbox(), myid())
	workers::Array = Tuple{Int, Any, Any}[]
	paramservers::Array = Tuple{Int, Any, Any}[]
	num_train_examples
	num_processed_examples=0
	num_epoch=1
	max_num_epochs
	time_var=now()
	compute_loss_timeout=5
	compute_loss_last=now()
	# parameters for adaptive control policy
	hyper_params

	num_workers
	num_paramservers
	# number of examples the master sends to worker in response to ExamplesRequestMessage
	num_live_workers=0
	num_live_pservers=0
	final_params=nothing
	starting_params::Parameter
	num_processed_params=0
	best=0.0
end

@with_kw type HyperParameters
	learning_rate
	examples_batch_size
	tau
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
		remotecall_fetch(PABASTO.initialize_view,id)
		ref = @spawnat id PABASTO.paramserver(state.master_mailbox, state.shared_pserver_mailbox,pserver_mailbox,index,state.starting_params,state.hyper_params)
		@async wait(ref)
		push!(state.paramservers, (id,ref,pserver_mailbox))
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
		ref = @spawnat id PABASTO.worker(id, state.master_mailbox, worker_mailbox,state.starting_params,state.hyper_params)
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
	while count < state.hyper_params.examples_batch_size && state.num_processed_examples < state.num_train_examples
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
	state.final_params=msg.parameters
end

function handle(state::MasterState,msg::TestLossMessage)
	println("[MASTER] Test accuracy is $(-msg.loss)")

	f = open("params$(
	@sprintf "%06d" msg.params.discrete_timestamp
	)-acc$(-msg.loss).jls", "w")
	serialize(f, msg.params)
	close(f)

end

function handle(state::MasterState,msg::Void)
	#println("[MASTER] Spinning")
	yield()
end

function master(;starting_params=SimpleParameter(sample_parameters(seed=1)))
	train_examples, train_labels = traindata()
 #starting_params=deserialize(open("params020015-acc0.749974839516982.jls","r"))

	hyper_params=HyperParameters(
	examples_batch_size=100,
	learning_rate=10,
	tau=1.0,
	)

	state = MasterState(
	num_train_examples=size(train_examples,2), 
	max_num_epochs=1000,
	num_workers=4,
	num_paramservers=1,
	hyper_params=hyper_params,
	starting_params=starting_params
	)
	initialize_nodes(state)

	while state.num_live_workers > 0
		handle(state,take!(state.master_mailbox))
		if Int(now()-state.compute_loss_last)>state.compute_loss_timeout*1000
			(id,ref,mailbox)=rand(state.workers)
			put!(mailbox,TestExampleIndicesMessage(1:300))
			state.compute_loss_last=now()
		end
	end

	state.num_paramservers = state.num_live_pservers

	# query the lead parameter server for 
		put!(state.paramservers[1][3], ParameterUpdateRequestMessage(state.master_mailbox))

		while state.final_params == nothing
			handle(state,take!(state.master_mailbox))
		end

		# We got parameters so shut down all the paramservers
		for (id, ref, pserver_mailbox) in state.paramservers
			put!(pserver_mailbox, CeaseOperationMessage())
		end

		# write params to disk
		f = open("params.jls", "w")
		serialize(f, state.final_params)
		close(f)

		for (id,ref,mailbox) in cat(1,state.paramservers,state.workers)
			wait(ref)
		end
	end
