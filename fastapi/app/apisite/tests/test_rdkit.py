import pytest
from sqlalchemy import select, func
from rdkit.Chem import AllChem as Chem
from razi.rdkit_postgresql.types import Mol, Reaction
from db import engine, Molecule, Base, SessionLocal

# Re-use Molecule model but with Mol type for 'm' column if we were to test insertion
# For now, we test the functions directly as in the original tests

@pytest.fixture(scope="module")
def db_session():
    Base.metadata.create_all(bind=engine)
    session = SessionLocal()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)

def test_mol_from_smiles(db_session):
    # rs = engine.execute(select([ func.is_valid_smiles('c1ccccc1') ]))
    # In SQLAlchemy 2.0+ (which might be used), we use session.execute(select(func...))
    
    val = db_session.execute(select(func.is_valid_smiles('c1ccccc1'))).scalar()
    assert val is True
    
    val = db_session.execute(select(func.mol_from_smiles('c1ccccc1'))).scalar()
    # Razi returns rdkit.Chem.Mol objects
    assert isinstance(val, Chem.Mol)
    
    val = db_session.execute(select(func.is_valid_smiles('c1cccc'))).scalar()
    assert val is False
    
    val = db_session.execute(select(func.mol_from_smiles('c1cccc'))).scalar()
    assert val is None

def test_mol_to_smiles(db_session):
    val = db_session.execute(
        select(func.mol_to_smiles(func.mol_from_smiles('c1ccccc1')))
    ).scalar()
    assert val == 'c1ccccc1'

def test_inchi_out(db_session):
    val = db_session.execute(select(func.mol_inchi(func.mol('c1ccccc1')))).scalar()
    assert val == 'InChI=1S/C6H6/c1-2-4-6-5-3-1/h1-6H'
    
    val = db_session.execute(select(func.mol_inchikey(func.mol('c1ccccc1')))).scalar()
    assert val == 'UHOVQNZJYSORNB-UHFFFAOYSA-N'

def test_props(db_session):
    val = db_session.execute(select(func.mol_amw(func.mol('c1ccccc1')))).scalar()
    assert pytest.approx(val, abs=1e-3) == 78.114
    
    val = db_session.execute(select(func.mol_logp(func.mol('c1ccccc1')))).scalar()
    assert pytest.approx(val, abs=1e-3) == 1.6866
    
    val = db_session.execute(select(func.mol_hba(func.mol('c1ccccc1')))).scalar()
    assert val == 0
    
    val = db_session.execute(select(func.mol_hbd(func.mol('c1ccccc1')))).scalar()
    assert val == 0

def test_mol_samestruct(db_session):
    val = db_session.execute(
        select(func.mol('Cc1ccccc1') == func.mol('c1ccccc1C'))
    ).scalar()
    assert val is True
    
    val = db_session.execute(
        select(func.mol('Cc1ccccc1') == func.mol('c1cnccc1C'))
    ).scalar()
    assert val is False

def test_reaction_ops(db_session):
    # Basic reaction tests
    val = db_session.execute(select(func.reaction_from_smiles('c1ccccc1>CC(=O)O>c1ccncc1'))).scalar()
    assert val is not None
    
    val = db_session.execute(select(func.reaction_numreactants(func.reaction_from_smiles('c1ccccc1>CC(=O)O>c1ccncc1')))).scalar()
    assert val == 1
    
    val = db_session.execute(select(func.reaction_numproducts(func.reaction_from_smiles('c1ccccc1>CC(=O)O>c1ccncc1')))).scalar()
    assert val == 1
