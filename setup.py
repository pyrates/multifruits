"""Tasty multipart form data parser built with cython."""
from pathlib import Path
from setuptools import setup, Extension

VERSION = (0, 1, 5)

setup(
    name="multifruits",
    version=".".join(map(str, VERSION)),
    description=__doc__,
    long_description=Path("README.md").read_text(),
    long_description_content_type="text/markdown",
    author="Pyrates",
    author_email="yohan.boniface@data.gouv.fr",
    url="https://github.com/pyrates/multifruits",
    classifiers=[
        "License :: OSI Approved :: MIT License",
        "Intended Audience :: Developers",
        "Programming Language :: Python :: 3",
        "Operating System :: POSIX",
        "Operating System :: MacOS :: MacOS X",
        "Environment :: Web Environment",
        "Development Status :: 4 - Beta",
    ],
    platforms=["POSIX"],
    license="MIT",
    ext_modules=[
        Extension(
            "multifruits",
            ["multifruits.c"],
            extra_compile_args=["-O3"],  # Max optimization when compiling.
        )
    ],
    provides=["multifruits"],
    include_package_data=True,
    extras_require={"dev": ["Cython==0.29.21"]}
)
