from setuptools import setup, find_namespace_packages

setup(
    name='bifrost_amrfinderplus',
    version='1.0.0',
    description='AMRfinder for Bifrost',
    url='https://github.com/ssi-dk/bifrost_amrfinderplus',

    # Author details
    author='Rasmus Henriksen',
    author_email='raah@ssi.dk',

    # Choose your license
    license='MIT',

    packages=find_namespace_packages(),
    install_requires=[
        'bifrostlib >= 2.0.11',
        'biopython>=1.77'
    ],
    python_requires='>=3.6',
    package_data={'bifrost_amrfinderplus': ['config.yaml', 'pipeline.smk']},
    include_package_data=True
)