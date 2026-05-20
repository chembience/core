from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# Database configuration
POSTGRES_USER = os.getenv("POSTGRES_USER", "chembience")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "secure-password-here")
POSTGRES_NAME = os.getenv("POSTGRES_NAME", "chembience")
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres")
POSTGRES_PORT = os.getenv("POSTGRES_INTERNAL_PORT", "5432")

SQLALCHEMY_DATABASE_URL = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_NAME}"

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Example Model
class Molecule(Base):
    __tablename__ = "molecules"
    id = Column(Integer, primary_key=True, index=True)
    smiles = Column(String, unique=True, index=True)

def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
