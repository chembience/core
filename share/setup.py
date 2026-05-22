from setuptools import setup, find_packages

setup(
    name="chembience",
    version="0.5.0",
    packages=find_packages(),
    install_requires=[
        "sqlalchemy",
        "psycopg2-binary",
    ],
)
