import os
from sqlalchemy import text
from rdkit import Chem
from rdkit.Chem import Draw
from chembience.db import engine

def check_connection():
    try:
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
