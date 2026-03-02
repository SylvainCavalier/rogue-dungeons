class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :character, dependent: :destroy

  def generate_auth_token!
    loop do
      self.auth_token = SecureRandom.hex(32)
      break unless User.exists?(auth_token: auth_token)
    end
    save!
    auth_token
  end

  def invalidate_auth_token!
    update!(auth_token: nil)
  end
end
