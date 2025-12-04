"""
Setup script for Hiddify Agent Traffic Manager
"""
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

# Define package name (with underscores for Python import)
PACKAGE_NAME = "hiddify_agent_traffic_manager"

setup(
    name="hiddify-agent-traffic-manager",
    version="1.0.0",
    author="Hiddify Agent Traffic Manager",
    description="ماژول مدیریت محدودیت ترافیک برای ایجنت‌ها در HiddifyPanel",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/smmnouri/hiddify-agent-traffic-manager",
    # Use find_packages but rename the root package
    packages=[pkg.replace('hiddify-agent-traffic-manager', PACKAGE_NAME) if 'hiddify-agent-traffic-manager' in pkg else pkg 
              for pkg in find_packages(exclude=['tests', '*.tests', '*.tests.*', 'tests.*'])],
    # Or manually specify packages
    # packages=[PACKAGE_NAME, f"{PACKAGE_NAME}.models", f"{PACKAGE_NAME}.utils", f"{PACKAGE_NAME}.tasks", f"{PACKAGE_NAME}.admin", f"{PACKAGE_NAME}.api"],
    package_dir={PACKAGE_NAME: '.'},
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

