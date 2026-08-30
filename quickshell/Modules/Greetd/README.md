# Embedded Greetd module

TODO: remove when adv-greeter is available in the Arch extra repos.

The greeter moved to [adv-greeter](https://github.com/bavanchun/adv-greeter). This embedded copy exists only for archinstall compatibility: the `niri - AriadnevShell` archinstall profile writes an `/etc/greetd/config.toml` that launches `Modules/Greetd/assets/advs-greeter` from the packaged ADVS tree, and adv-greeter is not installable from the official Arch repos yet.

Do not extend this module. New greeter work goes to adv-greeter. Installing greetd-advs-greeter-bin from the AUR and running `advs-greeter sync` migrates a system off this embedded copy.
