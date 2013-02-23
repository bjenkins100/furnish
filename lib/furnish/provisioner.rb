module Furnish
  #
  # Furnish provides no Provisioners as a part of its package. To use
  # pre-packaged provisioners, you must install additional packages.
  #
  # Provisioners are *objects* that have a simple API and as a result, there is
  # no "interface" for them in the classic term. You implement it, and if it
  # doesn't work, you'll know in a hurry.
  #
  # I'm going to say this again -- Furnish does not construct your object.
  # That's your job.
  #
  # Provisioners need 3 methods and one attribute, outside of that, you can do
  # anything you want.
  #
  # * name is an attribute (getter/setter) that holds a string. It is used in
  #   numerous places, is set by the ProvisionerGroup, and must not be volatile.
  # * startup(*args) is a method to bring the provisioner "up" that takes an
  #   arbitrary number of arguments and returns truthy or falsey, and in
  #   exceptional cases may raise. A falsey return value means that provisioning
  #   failed and the Scheduler will stop. A truthy value is passed to the next
  #   startup method in the ProvisionerGroup.
  # * shutdown is a method to bring the provisioner "down" and takes no
  #   arguments. Like startup, truthy means success and falsey means failed, and
  #   exceptions are fine, but return values aren't chained.
  # * report returns an array of strings, and is used for diagnostic functions.
  #   You can provide anything that fits that description, such as IP addresses
  #   or other identifiers.
  #
  # Tracking external state is not Furnish's job, that's for your provisioner.
  # Palsy is a state management system that Furnish links deeply to, so any
  # state tracking you do in your provisioner, presuming you do it with Palsy,
  # will be tracked along with Furnish's state information in the same
  # database. That said, you can do whatever you want. Furnish doesn't try to
  # think about your provisioner deadlocking itself because it's sharing state
  # with another provisioner, so be mindful of that.
  #
  # Additionally, while recovery of furnish's state is something it will do for
  # you, managing recovery inside your provisioner (e.g., ensuring that EC2
  # instance really did come up after the program died in the middle of waiting
  # for it) is your job. Everything will be brought up as it was and
  # provisioning will be restarted. Account for that.
  #
  module Provisioner
  end
end
