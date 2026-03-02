# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Créer un utilisateur de test (sans personnage)
# L'utilisateur sera redirigé vers la page de création de personnage lors de la connexion
user = User.find_or_create_by!(email: "test@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

puts "✓ Utilisateur créé: test@example.com"
puts "   Mot de passe: password123"

# Supprimer le personnage existant si présent (pour un reset)
user.character.destroy if user.character.present?

puts "\n✨ Tu pourras créer ton personnage avec tes propres stats lors de la connexion!"
