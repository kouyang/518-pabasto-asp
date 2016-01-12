using ClusterManagers

all_ids = addprocs(SlurmManager(250))
function add_pabasto_procs(count)
	@assert count <= length(all_ids)
	ids = all_ids[1:count]
	global all_ids = all_ids[count+1:end]
	refs=[remotecall(()->eval(Main, quote
		if myid() != 1
			#redirect_stderr(open("$(myid()).err", "w"))
			#redirect_stdout(open("$(myid()).out", "w"))
		end
		using PABASTO
	end), id)
	for id in ids
	]
	for ref in refs
		wait(ref)
	end
	return ids
end

using PABASTO

refs=[]
for start in ["0.5","0.7"]
	for learning_rate in [0.1,0.01,0.001]
		for num_workers in [2,4,8,16]
			starting_params=deserialize(open("intervals/$(start).jls","r"))
			hyper_params=PABASTO.HyperParameters(
			examples_batch_size=num_workers*3,
			learning_rate=learning_rate,
			tau=0.5,
			num_workers=num_workers,
			num_paramservers=1,
			max_num_epochs=10,
			)

			save_folder="$(start)-$(hyper_params)"
			run(`rm -rf $(save_folder)`)
			run(`mkdir -p $(save_folder)`)
			f=open("$(save_folder)/hyper_params.txt","w")
			println(f,hyper_params)
			close(f)
			save_folder="$(start)-$(hyper_params)/"

			master_id = add_pabasto_procs(1)[1]
			push!(refs,@spawnat master_id PABASTO.master(starting_params=starting_params,hyper_params=hyper_params,save_folder=save_folder))
		end
	end
end
for r in refs
	wait(r)
end
rmprocs(workers())
