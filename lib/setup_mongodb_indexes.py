# Script d'initialisation des index MongoDB pour les réservations
# Exécutez ce script une seule fois après l'intégration des routes

from pymongo import MongoClient, ASCENDING, DESCENDING
import os

def setup_bookings_indexes():
    """
    Crée les index nécessaires pour la collection bookings
    pour optimiser les performances des requêtes
    """

    # Connexion à MongoDB
    mongodb_uri = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/')
    database_name = os.getenv('DATABASE_NAME', 'wortis')

    try:
        client = MongoClient(mongodb_uri)
        db = client[database_name]
        bookings_collection = db['bookings']

        print("🔧 Création des index pour la collection 'bookings'...")

        # Index 1 : Pour la requête des créneaux occupés
        # Utilisé par GET /api/bookings/occupied-slots
        index1 = bookings_collection.create_index([
            ('date', ASCENDING),
            ('service_name', ASCENDING),
            ('status', ASCENDING)
        ], name='idx_date_service_status')
        print(f"✅ Index créé: {index1}")

        # Index 2 : Pour la recherche des réservations par téléphone
        # Utilisé par GET /api/bookings/user/<telephone>
        index2 = bookings_collection.create_index([
            ('telephone', ASCENDING)
        ], name='idx_telephone')
        print(f"✅ Index créé: {index2}")

        # Index 3 : Pour le tri par date de création
        # Améliore les performances des listes triées
        index3 = bookings_collection.create_index([
            ('created_at', DESCENDING)
        ], name='idx_created_at')
        print(f"✅ Index créé: {index3}")

        # Index 4 : Pour vérifier les conflits de créneaux
        # Utilisé par POST /api/bookings/create-reservation
        index4 = bookings_collection.create_index([
            ('date', ASCENDING),
            ('timeSlot', ASCENDING),
            ('service_name', ASCENDING),
            ('status', ASCENDING)
        ], name='idx_conflict_check', unique=False)
        print(f"✅ Index créé: {index4}")

        # Index 5 : Pour le statut de paiement
        # Améliore les requêtes sur payment_status
        index5 = bookings_collection.create_index([
            ('payment_status', ASCENDING)
        ], name='idx_payment_status')
        print(f"✅ Index créé: {index5}")

        # Index 6 : Pour les recherches par référence de paiement
        # Utilisé pour les webhooks et callbacks de paiement
        index6 = bookings_collection.create_index([
            ('payment_reference', ASCENDING)
        ], name='idx_payment_reference', sparse=True)
        print(f"✅ Index créé: {index6}")

        # Lister tous les index
        print("\n📋 Index existants dans la collection 'bookings':")
        for index in bookings_collection.list_indexes():
            print(f"  - {index['name']}: {index.get('key', {})}")

        print("\n✨ Configuration terminée avec succès!")
        print("💡 Les requêtes seront maintenant beaucoup plus rapides.")

        client.close()

    except Exception as e:
        print(f"❌ Erreur lors de la création des index: {str(e)}")
        print("Vérifiez votre connexion MongoDB et vos variables d'environnement.")

if __name__ == '__main__':
    print("=" * 60)
    print("  Setup MongoDB Indexes - Wortis Booking System")
    print("=" * 60)
    print()

    setup_bookings_indexes()
