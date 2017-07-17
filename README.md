# beaker-vmpooler

Beaker library to use vmpooler hypervisor

# How to use this wizardry
 
This is a gem that allows you to use hosts with [vmpooler](vmpooler.md) hypervisor with [beaker](https://github.com/puppetlabs/beaker). This gem is already included as [beaker dependency](https://github.com/puppetlabs/beaker/blob/master/beaker.gemspec#L59) for you, so you don't need to do anything special to use this gem's functionality with beaker.



# Spec tests

Spec test live under the `spec` folder. There are the default rake task and therefore can run with a simple command:
```bash
bundle exec rake test:spec
```

# Acceptance tests

We run beaker's base acceptance tests with this library to see if the hypervisor is working with beaker. There is a simple rake task to invoke acceptance test for the library:
```bash
bundle exec rake test:acceptance
```

# Contributing

Please refer to puppetlabs/beaker's [contributing](https://github.com/puppetlabs/beaker/blob/master/CONTRIBUTING.md) guide.

If you are making changes in beaker-vmpooler and simultaneously in beaker, please *comment and link* your beaker fork repo and branch name in your PR of beaker-vmpooler for testing on CI.
