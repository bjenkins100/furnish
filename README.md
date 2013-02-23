# Furnish

Furnish is a scheduler that thinks about dependencies and provisioning. It's
the core of the provisioning logic in
[chef-workflow](https://github.com/chef-workflow/chef-workflow).

Provisioners are just a pipeline of actions which raise and lower the existence
of... something. They encapsulate state, and the actions of dealing with that
state. While chef-workflow uses this for virtual machine and "cloud" things,
anything that has on and off state can be managed with Furnish.

Furnish is novel because it lets you walk away from the problem of dealing with
command pipelines and persistence, in a way that lets you deal with it
concurrently or serially without caring too much, making testing things that
use Furnish a lot easier. It has a number of guarantees it makes about this
stuff. See `Contracts` below.

Outside of that, it's just solving Dining Philosophers with Waiters and
cheating a little by knowing how MRI's thread scheduler works.

Furnish requires MRI Ruby 1.9.3 at minimum. It probably will explode violently
on a Ruby implemention that doesn't have a GVL or the I/O based coroutine
scheduler MRI has. If you don't like that, patches welcome.

## Installation

Add this line to your application's Gemfile:

    gem 'furnish'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install furnish

## Usage

```ruby
Furnish.init("state.db")
# set a logger if you want -- See Furnish::Logger for more info
Furnish.logger = Furnish::Logger.new(File.open('log', 'w'))
# start a scheduler and start spinning
scheduler = Furnish::Scheduler.new
scheduler.run # returns immediately

# or, start it serially
scheduler.serial = true
scheduler.run # blocks until provisions finish

# Provision something with a Provisioner -- See Furnish::ProvisionerGroup for
# how to write them.
scheduler.schedule_provision('some_name', [MyProvisioner.new])

# depend on other provisions
scheduler.schedule_provision('some_other_name', [MyProvisioner.new], %w[some_name])

# if you want to block the current thread, you can with the wait_for call
scheduler.wait_for('some_other_name') # waits until some_other_name provisions successfully.

# in threaded mode (the default), these would have already started. If you're
# in serial mode, you need to kick the scheduler:
scheduler.run # blocks until everything finishes

# tell the scheduler to stop -- still finishes what's there, just doesn't do
# anything new.
scheduler.stop

# shutdown furnish -- closes state database 
Furnish.shutdown
```

## Contracts

Furnish has high level contracts that it guarantees. These are expressed
liberally in the test suite, and any reported issue that can prove these are
violated is a blocker.

See Furnish::Scheduler and Furnish::ProvisionerGroup for what "provisioner"
means in this context.

* Furnish is a singleton and operates on a single database. Only one Furnish
  instance will exist for any given process.
* Furnish will never lose track of your state unless it is never given the
  opportunity to record it (e.g., `kill -9` or a hard power-off).
* Furnish will never deadlock dealing with state.
* Furnish, in threaded mode, will never block the provisioning process, and
  provisioners from one group cannot block another group via Furnish.
* If a provision crashes or fails:
  * Furnish will never crash as a result.
  * Furnish will stop processing new items and raise an exception when
    Furnish::Scheduler#running? is called.
  * Currently running items will continue in threaded mode, and their state
    will be dealt with accordingly.
  * Furnish will never get into an irrecoverable state -- you can clean up and
    start the scheduler again if that's what you need to do.
  * Furnish will never try to "fix" a failed provision. You are responsible for
    dealing with recovery.
* Furnish will always come with a serial mode to deal with bad actors (quite
  literally) in a toolkit-independent way, when possible.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
