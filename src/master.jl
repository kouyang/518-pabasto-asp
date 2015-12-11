using MNIST

### TYPE DEFINITION ###

type MasterState
	master_mailbox
	paramservers
	workers
	num_train_examples
	num_processed_examples
	num_epoch
	max_num_epoches
	time_var
	# parameters for adaptive control policy
	tau
	num_workers
	num_paramservers
	# number of examples the master sends to worker in response to ExamplesRequestMessage
	examples_batch_size
	# number of examples the worker processes to compute a gradient update
	batch_size
	gossip_time
	num_live_workers
	params
	num_processed_params
end

### INITIALIZATION ###

function initialize_nodes(state::MasterState)
	add_paramservers(state, state.num_paramservers)
	add_workers(state, state.num_workers)
end

function add_paramservers(state::MasterState, count)
	ids = add_procs(count)
	# todo: remove wait
	for id in ids
		pserver_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		remotecall_fetch(paramserver_setup, id, state.master_mailbox, pserver_mailbox)
		push!(state.paramservers, (id, pserver_mailbox))
	end
end

function remove_paramserver(state::MasterState)
	#=
	id, pserver_mailbox = pop!(state.paramservers)
	put!(pserver_mailbox, CeaseOperationMessage())
	=#
end

function add_workers(state::MasterState, count)
	ids = add_procs(count)
	for id in ids
		worker_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		ref = @spawnat id PABASTO.worker(id, state.master_mailbox, worker_mailbox)
		push!(state.workers, (id, ref, worker_mailbox))
	end
	state.num_live_workers += count
end

function remove_worker(state::MasterState)
	id, ref, worker_mailbox = pop!(state.workers)
	put!(worker_mailbox, CeaseOperationMessage())
	state.num_live_workers -= 1
end

### REQUEST HANDLING ###

# Handle request from workers for more examples
function handle(state::MasterState,request::ExamplesRequestMessage)

	if state.num_processed_examples >= state.num_train_examples && state.num_epoch < state.max_num_epoches
		state.num_processed_examples = 0;
		state.num_epoch = state.num_epoch + 1;
	elseif state.num_processed_examples >= state.num_train_examples
		# notify all workers to stop
		for (id, ref, worker_mailbox) in state.workers
			put!(worker_mailbox, FinishOperationMessage())
		end
		return;
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

function handle(state::MasterState,msg::GradientUpdateMessage)
	println("[MASTER] Dispatching GradientUpdateMessage")
	remotecall(handle,state.paramservers[rand(1:end)][1],msg)
end

function handle(state::MasterState,msg::ParameterUpdateRequestMessage)
	println("[MASTER] Dispatching ParameterUpdateRequestMessage")
	remotecall(handle,state.paramservers[rand(1:end)][1],msg)
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

	master_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), 1)

	workers = Tuple{Int, Any, Any}[]
	paramservers = Tuple{Int, Any}[]

	train_examples, train_labels = traindata()
	num_train_examples = size(train_examples, 2)
	num_processed_examples = 0
	num_epoch = 1
	max_num_epoches = 1
	time_var = now()

	# parameters for adaptive control policy
	tau = 20.0
	num_workers = 2
	num_paramservers = 1
	# number of examples the master sends to worker in response to ExamplesRequestMessage
	examples_batch_size = 500
	# number of examples the worker processes to compute a gradient update
	batch_size = 10
	gossip_time = 20.0
	num_live_workers = 0
	params = nothing
	num_processed_params = 0

	#REMOVE LATER
	num_train_examples = 10000;
	#REMOVE LATER
	flag = true

	# TO SEE GOSSIP WORK, set num_train_examples to 10,000, and num_paramservers to 2.
	# I suggest running code like julia main.jl > debug.txt so you can search through output

	state = MasterState(master_mailbox, paramservers, workers, num_train_examples, num_processed_examples, num_epoch, max_num_epoches, time_var, tau, num_workers, num_paramservers, examples_batch_size, batch_size, gossip_time, num_live_workers, params, num_processed_params)
	initialize_nodes(state)

	while state.num_live_workers > 0
		handle(state,take!(state.master_mailbox))

		# Check whether to initiate gossip
		time_elapsed = Int(now() - state.time_var)
		if num_paramservers > 1 && time_elapsed >= state.gossip_time * 1000

			# randomly choose 2 distinct paramservers

			pserver1_index = rand(1:length(state.paramservers));
			pserver1_id = state.paramservers[pserver1_index][1];

			# can do this because id is really stored in array
			sample_wo_replacement_paramservers = copy(state.paramservers);

			sample_wo_replacement_paramservers = deleteat!(sample_wo_replacement_paramservers, pserver1_index);

			pserver2_index = rand(1:length(sample_wo_replacement_paramservers));
			pserver2_id = sample_wo_replacement_paramservers[pserver2_index][1];

			# now dispatch the initiate gossip messages
			println("[MASTER] Dispatching InitiateGossipMessages")
			remotecall(handle, pserver1_id, InitiateGossipMessage(pserver2_id, pserver1_id))

			state.time_var = now();
		end

	end

	# query each paramserver for parameters
	# (todo: doesn't quite work yet; paramservers need to spin)
	for (id, pserver_mailbox) in paramservers
		remotecall(handle, id, ParameterRequestMessage())
	end

	while state.num_processed_params < num_paramservers
		handle(state,take!(state.master_mailbox))
	end

	# write params to disk
	f = open("params.out", "w")
	write(f, state.params.data)
	close(f)
end
