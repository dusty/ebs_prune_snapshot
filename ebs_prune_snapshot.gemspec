# -*- encoding: utf-8 -*-
require File.expand_path('../lib/ebs_prune_snapshot/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Dusty Doris"]
  gem.email         = ["dusty@doris.name"]
  gem.description   = %q{Prune EBS snapshots}
  gem.summary       = %q{Prune EBS snapshots on a daily, weekly, and monthly rotation}
  gem.homepage      = "https://github.com/dusty/ebs_prune_snapshot"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "ebs_prune_snapshot"
  gem.require_paths = ["lib"]
  gem.version       = EbsPruneSnapshot::VERSION

  gem.add_runtime_dependency('amazon-ec2')
end
