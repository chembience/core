from fastapi import FastAPI, Depends
from rdkit import Chem
from db import init_db, get_db
import os

app = FastAPI(title="Chembience FastAPI Prototype")

# Initialize database
init_db()

@app.get("/")
def read_root():
    return {"message": "Welcome to Chembience FastAPI Prototype"}

@app.get("/rdkit-info")
def rdkit_info():
    return {"rdkit_version": Chem.rdBase.rdkitVersion}

@app.get("/mol/{smiles}")
def get_mol(smiles: str):
    mol = Chem.MolFromSmiles(smiles)
    if mol:
        return {"smiles": smiles, "molblock": Chem.MolToMolBlock(mol)}
    return {"error": "Invalid SMILES"}
