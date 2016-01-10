using MNIST
const DISPLAY_FILTERS=false

if DISPLAY_FILTERS
	using Images, ImageView
end

### TYPE DEFINITION ###

@with_kw type MasterState
	master_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), myid())
	workers::Array = Tuple{Int, Any, Any}[]
	num_train_examples
	num_processed_examples=0
	num_epoch=1
	max_num_epochs
	time_var=now()
	compute_loss_timeout=5
	compute_loss_last=now()
	# parameters for adaptive control policy
	tau

	num_workers
	# number of examples the master sends to worker
	examples_batch_size
	num_live_workers=0
	num_working
	params::Parameter
	accumulated_gradients=SimpleGradient(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1])
	num_processed_params=0
end

### INITIALIZATION ###

function initialize_nodes(state::MasterState)
	add_workers(state, state.num_workers)
end

function add_workers(state::MasterState, count)
	ids = add_procs(count)
	for id in ids
		worker_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		ref = @spawnat id PABASTO.worker(id, state.master_mailbox, worker_mailbox,state.params)
		@async wait(ref)
		push!(state.workers, (id, ref, worker_mailbox))
	end
	state.num_live_workers += count
end

function remove_worker(state::MasterState)
	id, ref, worker_mailbox = pop!(state.workers)
	state.num_live_workers -= 1
	put!(worker_mailbox, FinishOperationMessage())
end

### REQUEST HANDLING ###

function handle(state::MasterState,msg::FinishedOperationMessage)
	state.num_live_workers -= 1
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
function handle(state::MasterState,message::GradientUpdateMessage)
	println("[MASTER] Accumulating gradients")
	state.accumulated_gradients.data += fetch(message.gradient).data

	if DISPLAY_FILTERS
		updateview(state)
	end
	state.num_working -= 1
end

function handle(state::MasterState,msg::TestLossMessage)
	println("[MASTER] Test loss is $(msg.loss)")
end

function handle(state::MasterState,msg::Void)
	println("[MASTER] Spinning")
	sleep(1)
end

function master(;starting_params=SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]))
	train_examples, train_labels = traindata()
	if DISPLAY_FILTERS
		global c = canvasgrid(4,5)
	end

	state = MasterState(
		num_train_examples=10000,#size(train_examples,2),
		max_num_epochs=1000,
		tau=20.0,
		num_workers=8,
		examples_batch_size=100,
		params=starting_params,
		num_working=0
	)
	initialize_nodes(state)

	while state.num_processed_examples < state.num_train_examples && state.num_epoch < state.max_num_epochs
		state.num_working = 0;
		for (id, ref, worker_mailbox) in state.workers
			count = 0;
			examples = []
			while count < state.examples_batch_size && state.num_processed_examples < state.num_train_examples
				example_id = state.num_processed_examples + 1
				push!(examples, example_id)
				count += 1
				state.num_processed_examples += 1
			end
			if (!isempty(examples))
				put!(worker_mailbox, ExampleIndicesMessage(examples))
				println("[MASTER] Assigned examples $(examples[1])-$(examples[end]) to worker $(id)")
				state.num_working += 1
			end
		end

		while state.num_working > 0
			handle(state,take!(state.master_mailbox))
		end
		update(state.params, state.accumulated_gradients)
		state.accumulated_gradients.data *= 0

		for (id, ref, worker_mailbox) in state.workers
			put!(worker_mailbox, ParameterUpdateMessage(state.params))
		end
	end

	for (id, ref, worker_mailbox) in state.workers
		put!(worker_mailbox, FinishOperationMessage())
	end

	while state.num_live_workers > 0
		handle(state,take!(state.master_mailbox))
		if Int(now()-state.compute_loss_last)>state.compute_loss_timeout*1000
			(id,ref,mailbox)=rand(state.workers)
			put!(mailbox,TestExampleIndicesMessage(1:100))
			state.compute_loss_last=now()
		end
	end

	# write params to disk
	f = open("params.jls", "w")
	serialize(f, state.params)
	close(f)
end
