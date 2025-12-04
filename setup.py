"""
Setup script for Hiddify Agent Traffic Manager
"""
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="hiddify-agent-traffic-manager",
    version="1.0.0",
    author="Hiddify Agent Traffic Manager",
    description="ماژول مدیریت محدودیت ترافیک برای ایجنت‌ها در HiddifyPanel",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/smmnouri/hiddify-agent-traffic-manager",
    packages=find_packages(exclude=['tests', '*.tests', '*.tests.*', 'tests.*']),
    package_dir={'': '.'},
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Internet :: WWW/HTTP :: Dynamic Content",
        "Topic :: System :: Networking",
    ],
    python_requires=">=3.8",
    install_requires=[
        "flask",
        "sqlalchemy",
        "flask-admin",
        "loguru",
        "flask-babel",
        "apiflask",
        "pydantic",
    ],
    extras_require={
        "dev": [
            "pytest",
            "pytest-cov",
            "black",
            "flake8",
        ],
    },
)

