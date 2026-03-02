module Api
  class BaseController < ActionController::Base
    protect_from_forgery with: :null_session
    before_action :authenticate_api_user!

    private

    def authenticate_api_user!
      token = request.headers["Authorization"]&.split("Bearer ")&.last
      @current_user = User.find_by(auth_token: token) if token.present?

      render json: { error: "Non authentifié" }, status: :unauthorized unless @current_user
    end

    def current_user
      @current_user
    end

    def current_character
      @current_character ||= current_user&.character
    end

    def require_character!
      return if current_character.present?

      render json: { error: "Aucun personnage créé" }, status: :not_found
    end

    def require_no_activity!
      return unless current_character&.busy?

      render json: {
        error: "Votre personnage est occupé",
        activity: current_character.activity,
        days_left: current_character.activity_days_left
      }, status: :unprocessable_entity
    end
  end
end
