import mysql.connector

# Connexion à la base
conn = mysql.connector.connect(
host='91.234.195.174',
        database='wortisbox_cg_afroglams0619',
        user='lez_cg_afrogla',
        password='s0619_one0059'
)

cursor = conn.cursor()

# Étape 1 : récupérer toutes les colonnes texte
cursor.execute("""
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = %s
  AND data_type IN ('char', 'varchar', 'text')
""", ("ta_base",))

columns = cursor.fetchall()

found = False  # pour savoir si on trouve quelque chose

# Étape 2 : rechercher 'PC_' dans chaque colonne
for table, column in columns:
    query = f"SELECT * FROM `{table}` WHERE `{column}` LIKE 'G2%';"
    cursor.execute(query)
    results = cursor.fetchall()
    if results:
        found = True
        print(f"\nTable: {table}, Colonne: {column}")
        for row in results:
            print(row)
        print("-" * 50)

if not found:
    print("Aucune valeur commençant par 'PC_' n'a été trouvée dans la base.")

cursor.close()
conn.close()
