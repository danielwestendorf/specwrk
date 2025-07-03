# frozen_string_literal: true

require_relative "lib/specwrk/version"

Gem::Specification.new do |spec|
  spec.name = "specwrk"
  spec.version = Specwrk::VERSION
  spec.authors = ["Daniel Westendorf"]
  spec.email = ["daniel@prowestech.com"]

  spec.summary = "Parallel rspec test runner from a queue of pending jobs."
  spec.homepage = "https://github.com/danielwestendorf/specwrk"
  spec.license = "LGPLv3"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage + "/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ spec/ scripts/ .git .github Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "dry-cli"
  spec.add_dependency "rack"
  spec.add_dependency "webrick"
  spec.add_dependency "rackup"
  spec.add_dependency "rspec-core"

  spec.add_development_dependency "webmock"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "rspec"
end
