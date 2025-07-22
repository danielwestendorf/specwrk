# frozen_string_literal: true

require "specwrk/queue"
require "specwrk/filestore"

module Specwrk
  class Web
    class << self
      def datastore
        Filestore
      end
    end
  end
end
