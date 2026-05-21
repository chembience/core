import os
from sqlalchemy import create_engine, text
from rdkit import Chem
from rdkit.Chem import Draw

# Database configuration from environment
POSTGRES_USER = os.getenv("POSTGRES_USER", "chembience")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "secure-password-here")
POSTGRES_NAME = os.getenv("POSTGRES_NAME", "chembience")
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres")
POSTGRES_PORT = os.getenv("POSTGRES_INTERNAL_PORT", "5432")

SQLALCHEMY_DATABASE_URL = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_NAME}"

def check_connection():
    try:
        engine = create_engine(SQLALCHEMY_DATABASE_URL)
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            print("✅ Database connection successful!")
            
            # Check for RDKit extension
            result = connection.execute(text("SELECT * FROM pg_extension WHERE extname = 'rdkit'"))
            if result.fetchone():
                print("✅ RDKit extension found in database!")
            else:
                print("❌ RDKit extension NOT found in database.")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")

def check_rdkit():
    try:
        mol = Chem.MolFromSmiles("c1ccccc1")
        print(f"✅ RDKit is working! Benzene has {mol.GetNumAtoms()} atoms.")
    except Exception as e:
        print(f"❌ RDKit is NOT working properly: {e}")

if __name__ == "__main__":
    print("--- Chembience Jupyter Environment Check ---")
    check_rdkit()
    check_connection()
