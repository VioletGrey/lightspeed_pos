require_relative 'collection'

require_relative 'credit_account'

module Lightspeed
  class CreditAccounts < Lightspeed::Collection
    alias_method :archive, :destroy
  end
end

