require_relative 'resource'

module Lightspeed
  class CreditAccount < Lightspeed::Resource
    alias_method :archive, :destroy

    fields(
      creditAccountID: :id,
      name: :string,
      code: :string,
      description: :string,
      giftCard: :boolean,
      archived: :boolean,
      customerID: :id,
      Contact: :hash,
      WithdrawalPayments: :hash,
      timeStamp: :datetime,
      balance: :decimal
    )
  end
end

