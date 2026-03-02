Rails.application.routes.draw do
  devise_for :users

  root to: "spa#index"

  namespace :api do
    # Auth
    post "auth/register", to: "auth#register"
    post "auth/login",    to: "auth#login"
    delete "auth/logout", to: "auth#logout"
    get "auth/me",        to: "auth#me"

    # Character
    resource :character, only: [:show, :create] do
      get :stats
    end

    # Skills
    resources :skills, only: [:index] do
      member do
        patch :upgrade
      end
    end

    # Inventory
    resources :inventory, only: [:index], controller: "inventory" do
      member do
        post :equip
        post :unequip
        post :use
      end
    end

    # Shop
    get "shop", to: "shop#index"
    post "shop/buy", to: "shop#buy"
    post "shop/sell", to: "shop#sell"

    # Town
    get "town/status", to: "town#status"
    post "town/work", to: "town#work"
    post "town/rest", to: "town#rest"
    post "town/academy/start", to: "town#academy_start"
    post "town/academy/advance", to: "town#academy_advance"
    post "town/guild/start", to: "town#guild_start"
    post "town/guild/advance", to: "town#guild_advance"
    get "town/available_magics", to: "town#available_magics"
    get "town/available_techniques", to: "town#available_techniques"

    # Tower & Combat
    get "tower", to: "tower#info"
    post "tower/enter", to: "tower#enter"
    get "tower/combat", to: "tower#combat"
    post "tower/combat/action", to: "tower#action"
    post "tower/flee", to: "tower#flee"

    # Test
    get "test", to: "test#index"
  end

  get "*path", to: "spa#index", constraints: ->(req) { !req.xhr? && req.format.html? }
end
