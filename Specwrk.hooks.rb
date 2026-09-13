# specwrk_hook_log = lambda do |event, **details|
#   specwrk_env = ENV.each_with_object({}) do |(name, value), values|
#     next unless name.start_with?("SPECWRK_")
#
#     values[name] = if name.match?(/KEY|TOKEN|SECRET|PASSWORD/)
#       "[REDACTED]"
#     else
#       value
#     end
#   end.sort.to_h
#
#   context = {
#     event: event,
#     pid: Process.pid,
#     ppid: Process.ppid,
#     specwrk_env: specwrk_env
#   }.merge(details)
#
#   puts context.map { |name, value| "#{name}=#{value.inspect}" }.join(" ")
# end
#
# Specwrk.before_seed do
#   specwrk_hook_log.call("before_seed")
# end
#
# Specwrk.after_seed do |examples|
#   specwrk_hook_log.call("after_seed", example_count: examples.length)
# end
#
# Specwrk.before_server_seed do
#   specwrk_hook_log.call("before_server_seed")
# end
#
# Specwrk.after_server_seed do |examples|
#   specwrk_hook_log.call("after_server_seed", example_count: examples.length)
# end
#
# Specwrk.before_worker_fork do
#   specwrk_hook_log.call("before_worker_fork")
# end
#
# Specwrk.after_worker_fork do
#   specwrk_hook_log.call("after_worker_fork")
# end
#
# Specwrk.before_worker_examples_execute do |examples|
#   specwrk_hook_log.call(
#     "before_worker_examples_execute",
#     example_count: examples.length,
#     example_ids: examples.map { |example| example[:id] }
#   )
# end
#
# Specwrk.after_worker_examples_execute do |examples|
#   specwrk_hook_log.call(
#     "after_worker_examples_execute",
#     example_count: examples.length,
#     example_ids: examples.map { |example| example[:id] }
#   )
# end
#
# Specwrk.before_worker_exit do |status|
#   specwrk_hook_log.call("before_worker_exit", status: status)
# end
#
# Specwrk.after_all_workers_exit do |status|
#   specwrk_hook_log.call("after_all_workers_exit", status: status)
# end
