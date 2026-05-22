from contextlib import asynccontextmanager

from fastapi import FastAPI
from rdkit import Chem

from db import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize database schema / extensions on startup.
    # Kept idempotent so concurrent workers are safe.
    init_db()
    yield


app = FastAPI(title="Chembience FastAPI Prototype", lifespan=lifespan)


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
