from sqlalchemy import Column, Integer, String
from razi.rdkit_postgresql.types import Mol
from chembience.db import Base


# Example Model
class Molecule(Base):
    __tablename__ = "molecules"
    id = Column(Integer, primary_key=True, index=True)
    smiles = Column(String, unique=True, index=True)
    m = Column(Mol, index=True)
