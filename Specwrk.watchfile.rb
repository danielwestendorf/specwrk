# Ignore all files which don't have an .rb extension
ignore(/^(?!.*\.rb$).+/)

# When a _spec.rb file changes, it should be run
map(/_spec\.rb$/) do |spec_path|
  spec_path
end

# If a file in lib changes, map it to the spec folder for it's spec file
map(/lib\/.*\.rb$/) do |path|
  path.gsub(/lib\/(.+)\.rb/, "spec/\\1_spec.rb")
end

# If a model file changes (assuming rails app structure), run the model's spec file
# map(/app\/models\/.*.rb$/) do |path|
#   path.gsub(/app\/models\/(.+)\.rb/, "spec/models/\\1_spec.rb")
# end
#
# If a controlelr file changes (assuming rails app structure), run the controller and system specs file
# map(/app\/controllers\/.*.rb$/) do |path|
#   [
#     path.gsub(/app\/controllers\/(.+)\.rb/, "spec/controllers/\\1_spec.rb"),
#     path.gsub(/app\/controllers\/(.+)\.rb/, "spec/system/\\1_spec.rb")
#   ]
# end
