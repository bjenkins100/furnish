* 0.1.0 (04/09/2013)
  * Furnish requires 1.9.3 or greater -- always has been the case, now rubygems enforces that for us.
  * Runtime performance increased significantly. No hard numbers, but test
    suite assertion count doubled and total test runtime actually dropped
    compared to 0.0.4. Yay.
  * Furnish::Provisioner::API is the new way to write provisioners. Please read its documentation.
    * Related, any existing provisioners will need significant changes to meet new changes.
    * Provisioners now have programmed property and object construction
      semantics, and the properties can now be queried, allowing for abstract
      provisioning logic.
  * Recovery mode: provisioners can opt-in to being able to recover from
    transient failures. See Furnish::ProvisionerGroup#recover for more
    information.
    * Related, Threaded mode schedulers no longer stop when when a provision
      fails. It instead marks Furnish::Scheduler#needs_recovery?
    * Failed provisions still keep any dependencies from starting, but
      independent provisions can still run.
    * Serial mode schedulers still have the same behavior when
      Furnish::Scheduler#run is called, but you can attempt to recover the
      scheduler from where the run threw an exception.
  * Furnish::Protocol is a way to specify what input and output provisioners
    operate on. Static checking will occur at scheduling time to ensure a
    provision can succeed (this is not a guarantee it will, just a way to
    determine if it definitely won't).
    * state transitions are now represented as hashes and merged over and
      passed on. this means for provisioner group consisting of A -> B -> C,
      that A can provide information that C can use without B knowing any
      better. This is enforced by the static checking Furnish::Protocol
      provides.
    * shutdown provisioner state transitions can now carry data between them.
  * Upgrade to palsy 0.0.4, which brings many consistency/durability/state
    management benefits for persistent storage use.
  * API shorthand for Furnish::Scheduler:
    * `<<` is now an alias for `schedule_provisioner_group`
    * `s` and `sched` are now aliases for `schedule_provision`
  * Probably some other shit I don't remember now.
* 0.0.4 (03/25/2013)
  * Support for FURNISH_DEBUG environment variable for test suites.
  * Ruby 2.0.0-p0 Compatibility Fixes
  * Documentation is RDoc 4.0 compatible.

* 0.0.3 (03/21/2013)
  * Fix an issue where state wasn't tracked for provisioners themselves after the provisioning process had started.

* 0.0.2 (03/20/2013)
  * Extract Furnish::TestCase into gem for consumption by other gems that need to test against furnish.

* 0.0.1 (02/23/2013)
  * Initial release as extracted from chef-workflow.
