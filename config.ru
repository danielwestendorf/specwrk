require "specwrk"
require "specwrk/web"
require "specwrk/web/app"

Specwrk::Web::App.setup!
run Specwrk::Web::App.rackup
