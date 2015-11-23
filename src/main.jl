#add n workers
function add_workers(n)
	#add logic for dataset division, and pass to PABASTO.worker
	new_process_ids=addprocs(n)
	for id in new_process_ids
		#todo: remove wait
		wait(@spawnat id (using PABASTO))
		ref=@spawnat id PABASTO.worker()
		push!(PABASTO.workers,(id,ref))
	end
end

#add n workers
function add_paramservers(n)
	new_process_ids=addprocs(n)
	for id in new_process_ids
		#todo: remove wait
		wait(@spawnat id (using PABASTO))
		push!(PABASTO.paramservers,id)
	end
end

using PABASTO
add_paramservers(1)
add_workers(3)


#wait for all workers to finish
for (id,ref) in PABASTO.workers
	fetch(ref)
end
