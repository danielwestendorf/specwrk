ignore(/^(?!.*\.rb$).+/)

map(/_spec\.rb$/) do |spec_path|
  spec_path
end

map(/lib\/.*\.rb$/) do |path|
  path.gsub(/lib\/(.+)\.rb/, "spec/\\1_spec.rb")
end

# map(/app\/models\/.*.rb$/) do |path|
#   path.gsub(/app\/models\/(.+)\.rb/, "spec/models/\\1_spec.rb")
# end
#
# map(/app\/controllers\/.*.rb$/) do |path|
#   [
#     path.gsub(/app\/controllers\/(.+)\.rb/, "spec/controllers/\\1_spec.rb"),
#     path.gsub(/app\/controllers\/(.+)\.rb/, "spec/system/\\1_spec.rb")
#   ]
# end
