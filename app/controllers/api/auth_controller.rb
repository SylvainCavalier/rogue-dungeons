module Api
  class AuthController < BaseController
    skip_before_action :authenticate_api_user!, only: [:register, :login]

    def register
      user = User.new(register_params)

      if user.save
        token = user.generate_auth_token!
        render json: {
          user: user_json(user),
          token: token
        }, status: :created
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def login
      user = User.find_by(email: login_params[:email])

      if user&.valid_password?(login_params[:password])
        token = user.generate_auth_token!
        render json: {
          user: user_json(user),
          token: token
        }
      else
        render json: { error: "Email ou mot de passe incorrect" }, status: :unauthorized
      end
    end

    def logout
      current_user.invalidate_auth_token!
      render json: { message: "Déconnecté" }
    end

    def update_password
      unless current_user.valid_password?(password_params[:current_password])
        return render json: { error: "Mot de passe actuel incorrect" }, status: :unprocessable_entity
      end

      if current_user.update(password: password_params[:password], password_confirmation: password_params[:password_confirmation])
        render json: { message: "Mot de passe mis à jour" }
      else
        render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def me
      render json: {
        user: user_json(current_user),
        character: current_character ? character_summary(current_character) : nil
      }
    end

    private

    def register_params
      params.require(:user).permit(:email, :password, :password_confirmation)
    end

    def login_params
      params.require(:user).permit(:email, :password)
    end

    def password_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
    end

    def user_json(user)
      {
        id: user.id,
        email: user.email,
        has_character: user.character.present?
      }
    end

    def character_summary(char)
      {
        id: char.id,
        name: char.name,
        current_hp: char.current_hp,
        max_hp: char.max_hp,
        current_mana: char.current_mana,
        max_mana: char.max_mana,
        xp: char.xp,
        gold: char.gold,
        current_floor: char.current_floor,
        date: char.formatted_date
      }
    end
  end
end
