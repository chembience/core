from contextlib import asynccontextmanager

from fastapi import APIRouter, FastAPI, HTTPException, status
from pydantic import BaseModel, Field
from rdkit import Chem

from chembience.db import init_db
from db.schema import Molecule  # noqa: F401  # ensure model is registered with Base.metadata


# --- Pydantic models ---------------------------------------------------------


class HealthResponse(BaseModel):
    status: str = Field(default="ok")


class RootResponse(BaseModel):
    message: str


class RDKitInfoResponse(BaseModel):
    rdkit_version: str


class MoleculeResponse(BaseModel):
    smiles: str
    molblock: str


# --- Lifespan ----------------------------------------------------------------


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize database schema / extensions on startup.
    # Kept idempotent so concurrent workers are safe.
    init_db()
    yield


app = FastAPI(title="Chembience FastAPI Prototype", lifespan=lifespan)


# --- Routers -----------------------------------------------------------------

meta_router = APIRouter(tags=["meta"])
chem_router = APIRouter(prefix="/chem", tags=["chem"])


@meta_router.get("/", response_model=RootResponse)
def read_root() -> RootResponse:
    return RootResponse(message="Welcome to Chembience FastAPI Prototype")


@meta_router.get("/healthz", response_model=HealthResponse)
def healthz() -> HealthResponse:
    return HealthResponse(status="ok")


@meta_router.get("/rdkit-info", response_model=RDKitInfoResponse)
def rdkit_info() -> RDKitInfoResponse:
    return RDKitInfoResponse(rdkit_version=Chem.rdBase.rdkitVersion)


@chem_router.get("/mol/{smiles}", response_model=MoleculeResponse)
def get_mol(smiles: str) -> MoleculeResponse:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid SMILES: {smiles!r}",
        )
    return MoleculeResponse(smiles=smiles, molblock=Chem.MolToMolBlock(mol))


app.include_router(meta_router)
app.include_router(chem_router)


# Backwards-compatible alias: old clients hit /mol/{smiles} directly.
@app.get("/mol/{smiles}", response_model=MoleculeResponse, include_in_schema=False)
def _get_mol_legacy(smiles: str) -> MoleculeResponse:
    return get_mol(smiles)
