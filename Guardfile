# vim: ft=ruby
guard 'minitest' do
  # with Minitest::Unit
  watch(%r!^test/(.*)\/?test_(.*)\.rb!)
  watch(%r!^test/(?:helper|mt_cases)\.rb!) { "test" }
end

guard 'rake', :failure_ok => true, :run_on_all => false, :task => 'rdoc_cov' do
  watch(%r!^lib/(.*)([^/]+)\.rb!)
end
